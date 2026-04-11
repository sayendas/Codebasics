Fleet Pulse: Real-Time Vehicle Telemetry Analytics Platform


Project Overview
Fleetage Mobility operates a commercial fleet equipped with IoT telemetry devices. This project delivers a real-time analytics platform to detect anomalies such as overspeeding, abnormal fuel drops, and temperature deviations. The solution will be built in two phases: hot-path real-time alerting and cold-path historical analytics.


Objectives
- Ingest raw telemetry into Confluent Cloud Kafka. Vehicle telemetry data production can be simulated through code.
- Process streams using Apache Flink to detect suspicious events.
- Trigger SMS/phone alerts via Azure Functions and Twilio.
- Deliver a fully functioning real-time POC.



