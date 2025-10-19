# TSA Certificates

Place TSA trust anchors here for RFC 3161 verification.

## FreeTSA CA

- `freetsa-ca.pem` — FreeTSA CA (self-signed). Download from the FreeTSA website and keep up to date.

### Verification

Verify timestamps with:

```bash
openssl ts -verify -data file -in file.tsr -CAfile ops/certs/freetsa-ca.pem
```

### Obtaining the CA Certificate

1. Visit [freetsa.org](https://www.freetsa.org/index_en.php)
2. Download their CA certificate (self-signed)
3. Save as `ops/certs/freetsa-ca.pem`

FreeTSA example usage and verification guidance is provided on their site.

## Notes

- **FreeTSA endpoint**: `https://freetsa.org/tsr`
- **Verification**: Requires their self-signed CA certificate
- **Alternative TSAs**: You can add commercial TSA certificates here (DigiCert, etc.)

## Adding Additional TSAs

To add more Time Stamp Authorities:

1. Obtain the TSA's CA certificate
2. Save as `ops/certs/<tsa-name>-ca.pem`
3. Update `ops/bin/remembrancer` to support the new TSA
4. Document the TSA endpoint and verification process here

