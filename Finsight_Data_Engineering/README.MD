FinSight Corp. receives daily transaction files from four regions—Asia, EMEA, North
America, and LATAM. These files are delivered to an AWS S3 bucket as part of their data
ingestion pipeline.

To stabilize downstream processing and analytics, FinSight requires a reliable and
traceable ingestion gatekeeper.

The objective is to design a serverless File-Level Validation System that acts as the first line of defense in
the ingestion pipeline.

The following checks would be performed file level 

Schema validation → ensure all required columns exist
Row-count check → log total and invalid rows
Null-Value Detection →

    Finance Table: Ensure no null or blank values in invoice_id, region, currency, date, source_system and amount.
    Sales Table: Ensure no null or blank values in order_id, region, customer_id, order_date, channel ,currency and sales_amount.

Valid data should be moved to bronze folder.
Rejected data should be moved to rejected folder.

