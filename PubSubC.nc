#include "Timer.h"
#include "printf.h"
#include "PubSub.h"

module PubSubC @safe() {

  uses {
  
	/****** INTERFACES *****/
	interface Boot;

    //interfaces for communication
	interface Receive;
    interface AMSend;
    interface SplitControl as AMControl;
    interface Packet;
    interface PacketAcknowledgements;
    
    //interfaces for serial communication
    interface Packet as SerialPacket;
    interface AMSend as SerialAMSend;
    interface SplitControl as SerialControl; 
    
	//interface for timers
	interface Timer<TMilli> as TimerCON;	// timer used to trigger the send of CONNECT messages
	interface Timer<TMilli> as TimerSUB;	// timer used to trigger the send of SUBSCRIBE messages
	interface Timer<TMilli> as TimerPUB;	// timer used to trigger the send of PUBLISH messages
	
	//interface for random number generation
	interface Random;
	
  }

} 

implementation {
  
  //***************** Variables definition ********************//
  
  message_t packet;
  message_t serial_packet;	//use a different packet variable for the serial communication  
  
  // array of boolean values. If connected_nodes[i] == 1 then NODE i+2 is connected to PAN coordinator
  uint8_t connected_nodes[N_CLIENTS];
  
  // boolean variable. Is TRUE if the node is connected to PAN coordinator
  bool is_connected = FALSE; 
  
  // array of topic tables (tables that contains the id of the nodes subscribed to a topic)
  topic_table_t topic_tables[N_TOPICS];
  
  
  //***************** Functions and procedures definition ********************//
  
  void initialize_pan_coord() {
  	/*
  	* Procedure that is called after booting. It initializes the array of connected clients and the 
  	* topic tables of the PAN coordinator 
  	*
  	*/
  	uint16_t i;
  	uint16_t j;
  	
  	// all clients are not connected to the PAN coordinator at the beginning
  	for (i = 0; i < N_CLIENTS; i++) {
  		connected_nodes[i] = 0;
  	}
  	
  	// no clients is subscribed to any topic at the beginning
  	for (j = 0; j < N_TOPICS; j++) {
  		topic_tables[j].limit = 0;
  	}
  }
  
  bool is_subscribed(uint16_t client_node_id, uint16_t topic_id) {
  	 /*
	  * Function that controls if a node is already subscribed to topic_id. In that case,
	  * TRUE is returned otherwise FALSE is returned
	  * @Input:
	  *		client_node_id: id of the node to control
	  *		topic_id: id of the topic 
	  */
	 uint16_t i;
	 uint16_t lim; 
	 bool found = FALSE;
	 
	 lim = topic_tables[topic_id].limit;
	 
	 for (i = 0; i < lim; i++) {
	 	if (topic_tables[topic_id].table[i] == client_node_id) 
	 		found = TRUE;
	 }
	 
	 return found;
  }
  
  void add_client_to_topic_table(uint16_t client_node_id, uint16_t topic_id) {
  	 /*
	  * Procedure that adds a client node to the table of nodes subscribed to topic_id
	  * @Input:
	  *		client_node_id: id of the node to add
	  *		topic_id: id of the topic 
	  */
	  uint16_t lim;
	  
	  lim = topic_tables[topic_id].limit;
	  
	  if (is_subscribed(client_node_id, topic_id)) {
	  	// the node is already subscribed to the topic. Exit.
	  	return;
	  }
	  
	  topic_tables[topic_id].table[lim] = client_node_id;
	  topic_tables[topic_id].limit++;
	  
  }
  
  int random_in_interval(int lower, int upper) {
  	 /*
	  * Function that generates a random integer number in the interval [lower, upper]
	  * and returns it
	  * @Input:
	  *		client_node_id: id of the node to control
	  *		topic_id: id of the topic 
	  */
	 int rn;	
	 rn = (call Random.rand16()) % (upper - lower + 1);
	 rn = rn + lower;
	 
	 return rn;
  }

  //***************** Boot interface ********************//
  
  event void Boot.booted() {
      //printf("Application booted on node %u.\n", TOS_NODE_ID);
      //printfflush();
      call AMControl.start(); 	
      
      if ( TOS_NODE_ID == PAN_COORD) {
      	//the PAN coordinator handles the serial communication
		call SerialControl.start();
	  }
  }

  //***************** SplitControl interface ********************//
  
  event void AMControl.startDone(error_t err) {
      
    if(err == SUCCESS) {
    	//printf("Radio on!\n");
	
		if (TOS_NODE_ID == PAN_COORD) {
        	initialize_pan_coord();
        }
        else {
        	// start the timer to send the CONNECT message
        	call TimerCON.startOneShot( 2000 );
        }
        
    }
    else{
		//dbg for error
		//printf("Radio start failed! Retry...\n");
		call AMControl.start();
    }
    
    //printfflush();

  }
  
  event void AMControl.stopDone(error_t err) { 
  	// do nothing
  }
  
  
  //***************** Serial SplitControl interface ********************//
  
  event void SerialControl.startDone(error_t err) {
   	
   	if(err == SUCCESS) {
		//printf("Serial radio on!\n");
    }
    else
	{
		//printf("Serial radio failed! Retry...\n");
		call SerialControl.start();
    }
    //printfflush();
  }
  
  event void SerialControl.stopDone(error_t err) {
  	// do nothing
  }
  
  
  //***************** MilliTimer interface ********************//
  
  event void TimerCON.fired() {
   
	// send a CONNECT message to the PAN coordinator. Ask also for an ACK
	
	connect_msg_t* mess = (connect_msg_t*)(call Packet.getPayload(&packet, sizeof(connect_msg_t)));
	if (mess == NULL) {
		return;
	}
	mess->type = CONNECT;
	mess->sender_node = TOS_NODE_ID;

	call PacketAcknowledgements.requestAck( &packet ); 	// ask for an ACK after the message to the PAN coordinator
	
	//send data to PAN coordinator
	if(call AMSend.send(PAN_COORD, &packet, sizeof(connect_msg_t)) == SUCCESS) {
		//printf("Sending CONNECT message... \n" );
	}
	
	//printfflush();	
  }
  
  event void TimerSUB.fired() {
  
  	// It is used by nodes to send a subscribe request to the PANC which answers with a SUBACK
  	sub_msg_t* mess = (sub_msg_t*)(call Packet.getPayload(&packet, sizeof(sub_msg_t)));
	mess->type = SUB;	//It fills the type field as SUB
  	
  
	if(TOS_NODE_ID != PAN_COORD) {	
	
		//if the nodeID is not the PANC then it can subscribe to the topics 
		uint16_t id = TOS_NODE_ID - 2;
		
		//use a deterministic method to decide the topics. In this way we wnsure that at least 3 nodes subscribe to more than one topic
	    mess->topics[0] = ((id & 0x1) != 0); 
	    mess->topics[1] = ((id & 0x2) != 0); 
	    mess->topics[2] = ((id & 0x4) != 0);   
	    if (TOS_NODE_ID == 2) {
	    	//force the subscription to topic 0 otherwise it would subscribe to no topic
	    	mess->topics[0] = 1;
	    }  	
	    mess->sender_node = TOS_NODE_ID;
		   
		//printf("Try to send a subscribe request to the PANC \n");
		call PacketAcknowledgements.requestAck( &packet );	//Asks for an ACK
	
		//Tries to send the packet to the PAN coordinator
		if(call AMSend.send(PAN_COORD, &packet, sizeof(sub_msg_t)) == SUCCESS){ 	
		  //printf("SUB request sent to PANC successfully!\n");
		  
		  //Displays the source, the type of the message and the topic which are subscribed to
		  //printf("\t\t Message type: %u \n", mess->type);
		  //printf("\t\t Topics: [%u %u %u] \n", mess->topics[0], mess->topics[1], mess->topics[2]);
		}
    }
    //printfflush();
    
  }
  
  event void TimerPUB.fired() {

  	pub_msg_t* mess = (pub_msg_t*)(call Packet.getPayload(&packet,sizeof(pub_msg_t)));
  	int payload;
  	uint16_t topicToSend;	
  	
    mess->type = PUB;
    topicToSend = random_in_interval(0,2);		// choose random topic
    mess->topic = topicToSend;
    mess->sender_node = TOS_NODE_ID;
    
    if (topicToSend == TEMP) 
    	payload = random_in_interval(0,MAX_TEMP);
    if (topicToSend == HUM) 
    	payload = random_in_interval(0,MAX_HUM);
    if (topicToSend == LUM) 
    	payload = random_in_interval(0,MAX_LUM);
    	
    mess->payload = payload;
    
    //printf("Try to send a publish message to the PANC \n");
	call PacketAcknowledgements.noAck( &packet );	// Do not ask for an ACK
	
	if(call AMSend.send(PAN_COORD, &packet, sizeof(pub_msg_t)) == SUCCESS){
		 //printf("PUB message sent to PANC successfully!\n");
		  
		 //Displays the source, the type of the message, the topic and the payload
		 //printf("\t\t Message type: %u \n", mess->type);
		 //printf("\t\t Topic: %u \n", mess->topic);
		 //printf("\t\t Payload: %d \n", mess->payload);
	}
	
	//printfflush();
  }
  

  //***************** Message interface ********************//
  
  event void AMSend.sendDone(message_t* buf, error_t error) {
  
  	// use connect_msg_t as default message type
  	connect_msg_t* mess = (connect_msg_t*)(call Packet.getPayload(&packet, sizeof(connect_msg_t)));
  	
    if (&packet == buf && error == SUCCESS) {
      	//printf("Packet sent \n");
      
   		if (mess->type == CONNECT) { 
			// The sent message is of type CONNECT
			if ( call PacketAcknowledgements.wasAcked(buf) ) { 
		  		//printf("Received a CONNACK! \n");
		  		is_connected = TRUE; // now the node is connected to the PAN coordinator
		  		call TimerSUB.startOneShot( 2000 ); //It starts to subscribe to the topic after 2 seconds
    		}
    		else {
    			//printf("CONNACK was not received... Retry \n");
    			call TimerCON.startOneShot( 2000 );		// retry to send the CONNECT after 2 seconds
    		}
    	}
    	
    	if (mess->type == SUB) { 
			// The sent message is of type SUB
			if ( call PacketAcknowledgements.wasAcked(buf) ) { 
		  		//printf("Received a SUBACK! \n");
		  		call TimerPUB.startPeriodic( 10000 ); //It starts to publish every 10 seconds
    		}
    		else {
    			//printf("SUBACK was not received... Retry \n");
    			call TimerSUB.startOneShot( 2000 );		// It sends again the SUBSCRIBE message after 2 seconds
    		}
    	}
    	
    	if (mess->type == PUB) {
    		// The sent message is of type PUB
    		//printf("The QoS of PUB messages is = 0 so we do not need an ACK \n");
    	}
    	 	
    }
    else {
      	//printf("Send done error! \n");
    }
    
    //printfflush();
  }

  event message_t* Receive.receive(message_t* bufPtr, void* payload, uint8_t len) {
	
    if (len != sizeof(connect_msg_t) && len != sizeof(sub_msg_t) && len != sizeof(pub_msg_t)) {
    	//printf("Receive error \n");
    	return bufPtr;
    }
    else {
      
      uint8_t msg_type;
       
      // We use the connect_msg_t data type as default data type for the receive. After reading the message type, if the received 
      // message is not a CONNECT, we type cast the message into sub_msg_t or pub_msg_t
      
      connect_msg_t* cm = (connect_msg_t*)payload;
      msg_type = cm->type;
      
      
      //-------------------------- Received message of type CONNECT --------------------------------
      
      if (msg_type == CONNECT) {
      
      	if (TOS_NODE_ID == PAN_COORD) {
      		// The node needs to do something only if it is the PAN coordinator
      		uint8_t sender_node = cm->sender_node;
      		//printf("Received CONNECT message from node %u.\n", sender_node);
      		
      		if (connected_nodes[sender_node - 2] == 0) {
      			// The sender node was not already connected. Mark it as connected
      			connected_nodes[sender_node - 2] = 1;
      		}
      		
      	}
      }
      
      
      //-------------------------- Received message of type SUB -------------------------------------
      
      if (msg_type == SUB) {
      
      	uint16_t i;
      	
      	// Parse the message as a message of data type sub_msg_t
      	sub_msg_t* sm = (sub_msg_t*)payload;
      	
      	if (TOS_NODE_ID == PAN_COORD) {
      		// The node needs to do something only if it is the PAN coordinator
      		uint8_t sender_node = sm->sender_node;
      		//printf("Received SUBSCRIBE message from node %u. \n", sender_node);
      		
      		if (connected_nodes[sender_node - 2] == 0) {
      			// The sender node is not connected, ignore the message
      			return bufPtr;
      		}
      	
		  	for (i = 0; i < N_TOPICS; i++) {
		  		
		  		if (sm->topics[i] == 1) {
		  			// add the sender node to the table of nodes subscribed to topic i
		  			add_client_to_topic_table(sender_node, i);
		  		}
		  	}	
		}
      		
      }
      
      
      //-------------------------- Received message of type PUB -------------------------------------      
     
      if (msg_type == PUB) {
      
      	pub_msg_t* mess;
      	pub_msg_t* serial_mess;

      	uint16_t i;
      	int j;
      	uint16_t destination_node;
      
		// Parse the message as a message of data type pub_msg_t
      	pub_msg_t* pm = (pub_msg_t*)payload;
      	
      	uint8_t sender_node = pm->sender_node;
      	//printf("Received PUBLISH message from node %u ", sender_node);
      	//printf("containing value %i ", pm->payload);
      	//printf("of topic %i \n", pm->topic);
      	
      	if (TOS_NODE_ID == PAN_COORD) {
      		// the PAN coordinator has to forward the PUB message to all nodes subscribed to the topic
      		uint8_t topic = pm->topic;
      		
      	
		  	if (connected_nodes[sender_node - 2] == 0) {
		  		// The sender node is not connected, ignore the message
		  		return bufPtr;
		  	}
		  	
		  	for (i = 0; i  < topic_tables[topic].limit; i++) {
		  		destination_node = (topic_tables[topic]).table[i]; 
		  		
		  		if (destination_node != sender_node) {
		  			// do not send the same publish message back to the publisher node
			  		mess = (pub_msg_t*)(call Packet.getPayload(&packet,sizeof(pub_msg_t)));
					if (mess == NULL) {
						return bufPtr;
					}
					mess->type = PUB;
					mess->sender_node = TOS_NODE_ID;
					mess->topic = topic;
					mess->payload = pm->payload;
					
					if(call AMSend.send(destination_node, &packet, sizeof(pub_msg_t)) == SUCCESS) {
						//printf("Forwarding PUBLISH message to node %u \n", destination_node);
					}	
					else {
						//printf("Failed to forward PUBLISH message to node %u \n", destination_node);
					}
						
				}
		  	
		  	}
			// forward the received PUB message to the serial channel
			serial_mess = (pub_msg_t*)(call SerialPacket.getPayload(&serial_packet,sizeof(pub_msg_t)));
			if (serial_mess == NULL) {
				//printf("Error in generating serial message \n");
				return bufPtr;
			}
			serial_mess->type = PUB;
			serial_mess->sender_node = TOS_NODE_ID;
			serial_mess->topic = pm->topic;
			serial_mess->payload = pm->payload;
			
			if(call SerialAMSend.send(AM_BROADCAST_ADDR, &serial_packet, sizeof(pub_msg_t)) == SUCCESS) {
				//printf("Forwarding PUBLISH message to serial channel \n");
			}	
			else {
				//printf("Failed to forward PUBLISH message to serial channel \n");
			}
      	
      	}
      		
      }
      
      return bufPtr;
      
    }
    
    //printfflush();
    
  }
  
  //********************* Serial Message interface ************************//
  
  event void SerialAMSend.sendDone(message_t* bufPtr, error_t error){
   	if (&serial_packet == bufPtr && error == SUCCESS) {
		//printf("Serial packet sent \n");
    }
    else {
      	//printf("Serial send done error! \n");
    }
    //printfflush();
  }

}


