# IoT-final-course-project
This is the final project for the Internet of Things course that I did together with a classmate. The work involves the use of several tools such as TinyOS, Node-RED, ThingSpeak and Cooja. 
The goal of the project is to design and implement in TinyOS a lightweight publishsubscribe application protocol similar to MQTT and test it with simulations on a star-shaped network topology composed of 8 client nodes connected to a PAN coordinator. The PAN coordinator acts as an MQTT broker. 
The nodes can send CONNECT, SUBSCRIBE or PUBLISH messages. In addition there are three topics (TEMPERATURE, HUMIDITY and LUMINOSITY) the nodes can subscribe to and/or publish data on. When a node publishes a message on a topic, this is received by the PAN and forwarded to all nodes that have subscribed to a particular topic.
The network is simulated in Cooja.
The PAN coordinator also sends periodically the received data on the topics to ThingsSpeak using NodeRED on the local machine.
