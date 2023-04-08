# Metatrader 5 MQTT Client Library

This is an MQTT client library for Metatrader 5, based on the @knolleary PubSubClient library.

## Features
- Supports MQTT version 3.1 and 3.1.1
- Connects to an MQTT broker over TCP/IP
- Supports both SSL and non-SSL connections
- Subscribes to and receives messages from MQTT topics
- Publishes messages to MQTT topics
- Supports QoS levels 0 and 1 for message publishing and subscription
- Handles MQTT connection errors and disconnections gracefully

## Installation

To use this library in your Metatrader 5 project, follow these steps:

- Download the latest release of the library from the Releases page.
- Extract the contents of the zip file to a folder in your project directory.
- In your Metatrader 5 project, include the MQTTClient.mqh file in your code using the #include directive.
There is an example code inside [example](example/) folder

## Usage
To use the MQTT client library, create an instance of the MQTTClient class and call its methods to connect to the broker, subscribe to topics, publish messages, and handle incoming messages.
Check [example/mqttTest.mq5](example/mqttTest.mq5) for an example.

Contributing
Contributions are welcome! If you would like to contribute to this project, please fork the repository, make your changes, and submit a pull request. Please make sure to follow the Contributing Guidelines when submitting your changes.

License
This library is licensed under the MIT License.
