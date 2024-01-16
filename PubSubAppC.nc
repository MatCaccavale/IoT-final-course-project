

#define NEW_PRINTF_SEMANTICS
#include "printf.h"
#include "PubSub.h"


configuration PubSubAppC {}

implementation {

  /****** COMPONENTS ******/
  components MainC, PubSubC as App, RandomC;
  components new AMSenderC(AM_PUB_SUB_MSG);
  components new AMReceiverC(AM_PUB_SUB_MSG);
  components ActiveMessageC;
  components SerialActiveMessageC;
  //components PrintfC;
  components SerialPrintfC;
  components new TimerMilliC() as timerCON; 	// timer used to trigger the send of CONNECT messages
  components new TimerMilliC() as timerSUB;		// timer used to trigger the send of SUBSCRIBE messages
  components new TimerMilliC() as timerPUB;		// timer used to trigger the send of PUBLISH messages

  
  /****** INTERFACES *****/
  //Boot interface
  App.Boot -> MainC.Boot;
  
  //Timer interface
  App.TimerCON -> timerCON;
  App.TimerSUB -> timerSUB;
  App.TimerPUB -> timerPUB;
  
  //Radio Control
  App.Receive -> AMReceiverC;
  App.AMSend -> AMSenderC;
  App.AMControl -> ActiveMessageC;
  App.PacketAcknowledgements->ActiveMessageC;
  App.Packet -> AMSenderC;
  
  // Serial Control
  App.SerialControl -> SerialActiveMessageC;
  App.SerialAMSend -> SerialActiveMessageC.AMSend[AM_SERIAL_PUB_SUB_MSG];
  App.SerialPacket -> SerialActiveMessageC;

  //Random numbers interface
  App.Random -> RandomC;
}


