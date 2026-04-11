Careplus is a company that analysis the various support logs and tickets from their customer care service in order to generate insights, data is extracted their S3 storage and cleaned, after which adhoc analysis is done via SQL and Power BI

1. Analytics / Query Layer (Top Flow)
Data is ingested into raw storage (likely object storage like S3).
Processed using serverless compute (Lambda-like).
Stored again in a processed/curated layer.
Finally queried using Ad-hoc SQL analytics (Amazon Athena-like).
2. Reporting / BI Layer (Bottom Flow)
Similar ingestion → raw → transformation → processed steps.
Data is loaded into a serverless data warehouse (Amazon Redshift-like).
Used for reporting and dashboards via Power BI.
