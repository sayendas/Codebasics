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

Above is a basic file validation task.




For the next requirement, the pipeline design is such that 

The system must:
1. Automatically trigger when a file is uploaded to S3.
2. Validate that the file is:
  In CSV format
  Contains actual data (not empty / not header-only)
3. Log the result (Validated or Failed) to a DynamoDB Audit table.

The files are uploaded in incoming folder.

The following checks are performed.

1. File Format Check
o Verify that the file extension is `.csv`.
o Action:
  If NOT .csv → FAIL validation.
2. Content Check
o Verify that the file:
  Is not empty
  Contains at least one data row in addition to the header
o Action:
  If empty or header-only → FAIL validation.

If Validation PASSES:
o Create the target date-partition folder if it does not already exist:
  validated/dt=<file_date>/
o Move the file into the above folder.
o Log status as Validated in DynamoDB.

If Validation FAILS:
o Create the target date-partition folder if it does not already exist:
  failed/dt=<file_date>/
o Move the file into the above folder.
o Log status as Failed in DynamoDB with failure reason.
