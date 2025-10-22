use anyhow::Result;
use serde::{Deserialize, Serialize};
use tracing::{info_span, Instrument};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Job {
    pub id: String,
    pub ops: Vec<Op>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", content = "data")]
pub enum Op {
    Add { x: i64 },
    Mul { x: i64 },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Outcome {
    pub ok: bool,
    pub final_value: i64,
    pub receipt_hint: Option<String>,
}

#[derive(Debug, Default, Clone, Serialize, Deserialize)]
pub struct State {
    pub value: i64,
}

impl Job {
    pub async fn run(self) -> Result<Outcome> {
        let span = info_span!("job", id = %self.id);
        async move {
            let mut s = State::default();
            for (i, op) in self.ops.iter().enumerate() {
                let step = info_span!("op", idx = i as i64);
                match op {
                    Op::Add { x } => {
                        (async { s.value += x }).instrument(step).await;
                    }
                    Op::Mul { x } => {
                        (async { s.value *= x }).instrument(step).await;
                    }
                }
            }
            Ok(Outcome {
                ok: true,
                final_value: s.value,
                receipt_hint: None,
            })
        }
        .instrument(span)
        .await
    }
}
