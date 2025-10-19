#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
message-queue.sh — add MQ client skeleton (RabbitMQ or NATS) to a service.

Usage:
  generators/message-queue.sh <service-name> [--dir <dest>] [--type rabbitmq|nats]

Defaults:
  --dir services/<service-name>
  --type rabbitmq

Outputs:
  - <dest>/mq/mq.py (Python async producer/consumer skeleton)
  - updates pyproject.toml with required deps if missing
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -lt 1 ]]; then
  usage; exit 0
fi

SERVICE="$1"; shift || true
DEST="services/${SERVICE}"
TYPE="rabbitmq"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) DEST="$2"; shift 2;;
    --type) TYPE="$2"; shift 2;;
    *) echo "Unknown arg: $1"; usage; exit 1;;
  esac
done

mkdir -p "${DEST}/mq"

case "${TYPE}" in
  rabbitmq)
    cat > "${DEST}/mq/mq.py" <<'PY'
import os, json, asyncio, uuid, time
import aio_pika

RABBIT_URL = os.getenv("C3L_RABBIT_URL", "amqp://guest:guest@localhost/")
EXCHANGE   = os.getenv("C3L_EXCHANGE", "c3l.events")
ROUTING    = os.getenv("C3L_ROUTING", "vaultmesh.event.*")

async def publish(event_type: str, data: dict):
    conn = await aio_pika.connect_robust(RABBIT_URL)
    async with conn:
        ch = await conn.channel()
        ex = await ch.declare_exchange(EXCHANGE, aio_pika.ExchangeType.TOPIC, durable=True)
        evt = {
            "specversion":"1.0",
            "id": str(uuid.uuid4()),
            "source": f"vm://{os.getenv('C3L_SERVICE', 'unknown')}",
            "type": event_type,
            "time": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "datacontenttype":"application/json",
            "data": data,
            "traceparent": os.getenv("TRACEPARENT","00-"+uuid.uuid4().hex+"-"+uuid.uuid4().hex[:16]+"-01")
        }
        msg = aio_pika.Message(body=json.dumps(evt).encode("utf-8"), delivery_mode=aio_pika.DeliveryMode.PERSISTENT)
        await ex.publish(msg, routing_key=event_type)
        return evt["id"]

async def consume(queue_name: str, pattern: str):
    conn = await aio_pika.connect_robust(RABBIT_URL)
    async with conn:
        ch = await conn.channel()
        await ch.set_qos(prefetch_count=20)
        ex = await ch.declare_exchange(EXCHANGE, aio_pika.ExchangeType.TOPIC, durable=True)
        q = await ch.declare_queue(queue_name, durable=True, arguments={
            "x-dead-letter-exchange": "c3l.dlx",
            "x-dead-letter-routing-key": "dead.events",
        })
        await q.bind(ex, routing_key=pattern)
        async with q.iterator() as it:
            async for m in it:
                try:
                    payload = json.loads(m.body.decode("utf-8"))
                    # TODO: handle(payload)
                    await m.ack()
                except Exception:
                    await m.reject(requeue=False)

if __name__ == "__main__":
    asyncio.run(consume(os.getenv("C3L_QUEUE","c3l.worker"), ROUTING))
PY
    ;;
  nats)
    cat > "${DEST}/mq/mq.py" <<'PY'
import os, json, asyncio, uuid, time
import nats
from nats.js.api import RetentionPolicy, StreamConfig, ConsumerConfig

NATS_URL = os.getenv("C3L_NATS_URL", "nats://localhost:4222")
STREAM   = os.getenv("C3L_STREAM", "C3L")
SUBJECT  = os.getenv("C3L_SUBJECT", "vaultmesh.event.*")

async def ensure_stream(js):
    try:
        await js.add_stream(StreamConfig(name=STREAM, subjects=[SUBJECT], retention=RetentionPolicy.WorkQueue))
    except Exception:
        pass

async def publish(event_type: str, data: dict):
    nc = await nats.connect(servers=[NATS_URL])
    js = nc.jetstream()
    await ensure_stream(js)
    evt = {
        "specversion":"1.0",
        "id": str(uuid.uuid4()),
        "source": f"vm://{os.getenv('C3L_SERVICE', 'unknown')}",
        "type": event_type,
        "time": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "datacontenttype":"application/json",
        "data": data
    }
    await js.publish(event_type, json.dumps(evt).encode("utf-8"))
    await nc.close()
    return evt["id"]

async def consume(durable: str, pattern: str):
    nc = await nats.connect(servers=[NATS_URL])
    js = nc.jetstream()
    await ensure_stream(js)
    psub = await js.pull_subscribe(pattern, durable=durable, config=ConsumerConfig(durable_name=durable))
    while True:
        msgs = await psub.fetch(10, timeout=5)
        for m in msgs:
            try:
                payload = json.loads(m.data.decode("utf-8"))
                # TODO: handle(payload)
                await m.ack()
            except Exception:
                await m.term()
    await nc.close()

if __name__ == "__main__":
    asyncio.run(consume(os.getenv("C3L_DURABLE","C3L_WORKER"), SUBJECT))
PY
    ;;
  *)
    echo "Unknown type: ${TYPE}"; exit 1;;
esac

# pyproject deps
PY="${DEST}/pyproject.toml"
if [[ ! -f "${PY}" ]]; then
  cat > "${PY}" <<'PYPROJECT'
[project]
name = "vaultmesh-__SERVICE_NAME__"
version = "0.1.0"
requires-python = ">=3.10"
dependencies = []
PYPROJECT
  sed -i.bak "s/__SERVICE_NAME__/${SERVICE}/g" "${PY}" || true
fi

if ! grep -q 'aio_pika' "${PY}" && [[ "${TYPE}" == "rabbitmq" ]]; then
  awk '/dependencies = \[/ {print; print "  \"aio-pika>=9.4\","; next}1' "${PY}" > "${PY}.tmp" && mv "${PY}.tmp" "${PY}"
fi
if ! grep -q 'nats-py' "${PY}" && [[ "${TYPE}" == "nats" ]]; then
  awk '/dependencies = \[/ {print; print "  \"nats-py>=2.7\","; next}1' "${PY}" > "${PY}.tmp" && mv "${PY}.tmp" "${PY}"
fi

echo "✅ MQ skeleton (${TYPE}) added to '${SERVICE}' at ${DEST}/mq/mq.py"