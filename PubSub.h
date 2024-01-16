
#ifndef PUB_SUB_H
#define PUB_SUB_H

//Definition the PAN coordinator node
#define PAN_COORD 1

//Definition of the number of client nodes
#define N_CLIENTS 8

//Definition of the number of topics
#define N_TOPICS 3

//Definition of numeric identifiers for the topics
#define TEMP 0
#define HUM 1
#define LUM 2

//Definition of maximum values that can be used to random generate the payload of each topic
#define MAX_TEMP 30
#define MAX_HUM 10
#define MAX_LUM 50

//Definition of the types of exchanged messages
#define CONNECT 0
#define SUB 1
#define PUB 2

//Definition of CONNECT messages data type. It is also used as standard type to parse the
//received messages and read the type
typedef nx_struct connect_msg {
	nx_uint8_t type;
	nx_uint8_t sender_node; 	
} connect_msg_t;

//Definition of SUBSCRIBE messages data type
typedef nx_struct sub_msg {
	nx_uint8_t type;
	nx_uint8_t sender_node; 
	nx_uint8_t topics[3];	//Array of boolean values: topics[i] == 1 if the node subscribes to topic i
} sub_msg_t;

//Definition of PUBLISH messages data type
typedef nx_struct pub_msg {
	nx_uint8_t type;
	nx_uint8_t sender_node;
	nx_uint8_t topic; 
	nx_uint16_t payload;		
} pub_msg_t;

// Data type definition of topic table (that is a table containing the clients that are subscribed to a certain topic)
typedef nx_struct topic_table {
	nx_uint16_t limit;					// The index of the last valid element in the table is equal to limit-1
	nx_uint16_t table[N_CLIENTS];		// Array of client nodes that are subscribed to a topic
} topic_table_t;

enum {
  AM_PUB_SUB_MSG = 10,
};

enum {
  AM_SERIAL_PUB_SUB_MSG = 137,
};

#endif
