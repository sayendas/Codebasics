----------------------------------------------------------------------------------------------------------------------------------
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



----------------------------------------------------------------------------------------------------------------------------------------------------------
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


--------------------------------------------------------------------------------------------------------------------------------------------------
Initially, we established a File-Level Gatekeeper that ensures only structurally valid CSV files enter the pipeline.
These validated files are now available in the validated/ folder.

However, even structurally valid files may still contain dirty or inconsistent data at the row level, 
such as:
 Negative transaction amounts (e.g., -500)
 Inconsistent region naming (e.g., "North America" vs "NA")
 Currency mismatches (e.g., Region = "Asia" but Currency = "USD")
To ensure data reliability for analytics and reporting, a row-level data quality processing layer is required.

For the next requirement, we build a pipeline which would take records from the validated folder and perform row level checks and data cleaning on it.

The system must:
1. Trigger automatically when a file lands in the validated/ folder
2. Read and process each row in the CSV file
3. Apply business validation and standardization rules
4. Separate clean and dirty records
5. Persist data quality metrics in DynamoDB for observability

Source
 validated/dt=YYYY-MM-DD/
Destinations
 processed/dt=YYYY-MM-DD/ → Clean, analytics-ready rows
 rejected/dt=YYYY-MM-DD/ → Rows that failed validation

For each CSV file, the Lambda function must loop through every row and apply the following
checks in order:
1. Null Check
o Ensure `transaction_id` is not empty
o Action:
 If empty → Reject the row
2. Region Standardization & Validation
o If region is "North America", standardize it to "NA"
o Ensure region is one of ['Asia', 'EMEA', 'NA', 'LATAM']
o Action:
 If region is invalid → Reject the row

3. Transaction Amount Validation
o `transaction_amount` must:
 Be numeric
 Be greater than 0
o Action:
 If zero or negative → Reject the row
4. Currency-to-Region Consistency Check
Ensure currency aligns with region:
Region Expected Currency
Asia INR
EMEA EUR
NA USD
LATAM BRL

Action:
 If mismatch (e.g., Asia + USD) → Reject the row

Valid Rows
o Written to:
 processed/dt=YYYY-MM-DD/
 Invalid Rows
o Written to:
 rejected/dt=YYYY-MM-DD/

For each file processed, write a data quality audit record with the following metrics:
Attribute Description
dq_id Unique UUID for the DQ run
file_name (PK) Name of the processed file
total_records Total number of rows in input file
valid_records Count of rows written to processed/
invalid_records Count of rows written to rejected/
dq_score (valid_records / total_records) * 100
processing_timestamp ISO-format timestamp

----------------------------------------------------------------------------------------------------------------------------------------------------

