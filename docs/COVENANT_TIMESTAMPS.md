# RFC 3161 Timestamps (v3.0)

## Why Timestamps?

RFC 3161 Time-Stamp Protocol (TSP) provides cryptographic proof that an artifact existed at or before a specific time. This enables:

- **Non-repudiation**: Prove when an artifact was created
- **Legal compliance**: Court-admissible proof of existence
- **Audit trails**: Tamper-proof chronological records
- **Trust**: Independent third-party attestation

## How It Works

1. **Request**: Hash the artifact, create timestamp request (`.tsq`)
2. **Submit**: Send request to Time Stamp Authority (TSA)
3. **Receive**: TSA returns signed timestamp token (`.tsr`)
4. **Verify**: Validate token against artifact and TSA certificate

## Create a Timestamp

```bash
# Using the Remembrancer
remembrancer timestamp dist/artifact.tar.gz
# Creates: dist/artifact.tar.gz.tsq (request)
#          dist/artifact.tar.gz.tsr (response token)

# Manual timestamp creation
openssl ts -query -data dist/artifact.tar.gz -sha256 -cert -out artifact.tsq
curl -sS -H "Content-Type: application/timestamp-query" \
  --data-binary "@artifact.tsq" \
  https://freetsa.org/tsr > artifact.tsr
```

## Verify a Timestamp

```bash
# Using the Remembrancer (full chain)
remembrancer verify-full dist/artifact.tar.gz

# Manual verification (requires TSA CA certificate)
openssl ts -verify \
  -data dist/artifact.tar.gz \
  -in dist/artifact.tar.gz.tsr \
  -CAfile ops/certs/freetsa-ca.pem
```

## Time Stamp Authorities

### FreeTSA (Default)

- **Endpoint**: `https://freetsa.org/tsr`
- **Type**: Public, free, Bitcoin-anchored
- **CA Certificate**: Self-signed (must be obtained from FreeTSA website)
- **Trust**: Community-operated, anchored to Bitcoin blockchain

**Obtaining FreeTSA CA Certificate**:
1. Visit [freetsa.org](https://www.freetsa.org/index_en.php)
2. Download their self-signed CA certificate
3. Save as `ops/certs/freetsa-ca.pem`

### Commercial TSAs

For production deployments requiring legal-grade timestamps:

- **DigiCert**: Industry-standard, widely trusted
- **GlobalSign**: International recognition
- **Sectigo**: Cost-effective commercial option

**Configuration**:
```bash
# Use a different TSA
remembrancer timestamp artifact.tar.gz https://tsa.example.com/tsr

# Or set default in environment
export DEFAULT_TSA_URL="https://tsa.example.com/tsr"
```

## OpenSSL `ts` Command

### Generate Timestamp Request

```bash
openssl ts -query \
  -data file.tar.gz \
  -sha256 \
  -cert \
  -out file.tsq
```

**Options**:
- `-data <file>`: File to timestamp
- `-sha256`: Use SHA-256 hash algorithm
- `-cert`: Request TSA certificate in response
- `-out <file>`: Output request file

### Submit to TSA

```bash
curl -H "Content-Type: application/timestamp-query" \
  --data-binary "@file.tsq" \
  https://freetsa.org/tsr > file.tsr
```

### Verify Timestamp Token

```bash
openssl ts -verify \
  -data file.tar.gz \
  -in file.tsr \
  -CAfile ops/certs/freetsa-ca.pem
```

**Options**:
- `-data <file>`: Original file
- `-in <file>`: Timestamp response token
- `-CAfile <file>`: TSA CA certificate

## Best Practices

### Security

- **Verify TSA certificate**: Always validate the TSA's CA certificate
- **Multiple TSAs**: Use multiple TSAs for critical artifacts
- **Regular validation**: Periodically re-verify timestamps
- **CA trust**: Only trust reputable TSA providers

### Operational

- **Archive tokens**: Store `.tsr` files alongside artifacts
- **Document TSA choice**: Record which TSA was used
- **Fallback TSAs**: Configure backup TSAs for availability
- **Timestamp receipts**: Include timestamps in Remembrancer receipts

### Legal Considerations

- **Admissibility**: Use legally recognized TSAs for court evidence
- **Jurisdiction**: Consider TSA location for legal compliance
- **Retention**: Preserve timestamps for required retention periods
- **Chain of custody**: Maintain complete timestamp verification chain

## Proof Bundles

Export complete proof (artifact + signature + timestamp):

```bash
remembrancer export-proof dist/artifact.tar.gz
# Creates: dist/artifact.proof.tgz
# Contains: artifact.tar.gz, artifact.tar.gz.asc, artifact.tar.gz.tsr
```

## Troubleshooting

### "TSA certificate not trusted"

```bash
# Verify you have the correct CA certificate
openssl x509 -in ops/certs/freetsa-ca.pem -text -noout

# If missing, download from TSA website
```

### "Timestamp verification failed"

```bash
# Check timestamp token contents
openssl ts -reply -in artifact.tsr -text

# Verify hash matches
sha256sum artifact.tar.gz
```

### Network issues with TSA

```bash
# Test TSA endpoint
curl -I https://freetsa.org/tsr

# Use alternative TSA if unreachable
remembrancer timestamp artifact.tar.gz https://alternative-tsa.com/tsr
```

## Advanced: Self-Hosted TSA

For complete sovereignty, you can run your own TSA:

```bash
# OpenSSL can act as a simple TSA
# See OpenSSL documentation for configuration

# Configure openssl.cnf with TSA section
# Run: openssl ts -reply -config openssl.cnf ...
```

## Integration with Remembrancer

Timestamps are automatically:
- Stored in `ops/receipts/` alongside deployment records
- Indexed in SQLite audit database (`ops/data/remembrancer.db`)
- Included in Merkle tree computation for audit integrity
- Verified during `remembrancer verify-full` checks

## References

- [RFC 3161 - Time-Stamp Protocol (TSP)](https://www.rfc-editor.org/rfc/rfc3161)
- [OpenSSL ts command](https://docs.openssl.org/3.2/man1/openssl-ts/)
- [FreeTSA](https://www.freetsa.org/)
- [The Remembrancer CLI](../ops/bin/remembrancer)

---

**Status**: Implemented in v3.0 Covenant Foundation  
**ADR**: See [ADR-008: RFC3161 over Blockchain](../ops/receipts/adr/ADR-008-rfc3161-over-blockchain.md)

