//+------------------------------------------------------------------+
//|                                                     mqttTest.mq5 |
//|                  Copyright 2023, Nicholas O'Leary, German Martin |
//|                        https://github.com/knolleary/pubsubclient |
//|                      https://github.com/gmag11/MQTT-MQL5-Library |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Nicholas O'Leary, German Martin"
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Mqtt/PubSubClient.mqh>

input string broker = "test.mosquitto.org";     // MQTT server (broker) address
input uint16_t port = 8883;                     // Broker TCP port
input string mqttuser = "";                     // User, if needed
input string mqttpassword = "";                 // Password, if needed
input bool useTLS = true;                       // Use encrypted communication
input string baseTopic = "metatrader";          // Base topic

//int socket;
PubSubClient* mqtt;

void reconnect() {
  // Loop until we're reconnected
  while (!mqtt.connected()) {
    Print("Attempting MQTT connection...");
    // Attempt to connect
    if (mqtt.connect("MQL5_Client",mqttuser,mqttpassword,useTLS)) {
      Print("connected");
      // Subscribe to required topics
      string topic = baseTopic + "/in";
      if (mqtt.subscribe(topic)) {
         printf("Subscription to topic %s correct", topic);
      } else {
         printf("Subscription to topic %s not correct", topic);
      }
      // Once connected, publish an announcement...
      time_t currentTime = TimeLocal();
      MqlDateTime dt;
      TimeToStruct(currentTime,dt);
      string payload = StringFormat("%04d-%02d-%02d %02d:%02d:%02d",dt.year,dt.mon,dt.day,dt.hour,dt.min,dt.sec);
      topic = baseTopic + "/start";
      printf("Publishing message: %s - %s", topic, payload);
      mqtt.publish(topic,payload,true);
    } else {
      printf("failed, rc=%d try again in 5 seconds", mqtt.state());
      // Wait 5 seconds before retrying
      Sleep(5000);
    }
  }
}

void onreceive(string& topic, uint8_t& payload[], uint payloadLength) {
   printf("Callback. %d bytes payload", payloadLength);
   string pld = CharArrayToString(payload,0,payloadLength);
   printf("%s: %s.20", topic, pld);
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   mqtt = new PubSubClient(broker, port);
   if (mqtt.state() == OBJECT_CREATION_ERROR) {
      Print("Mqtt object creation error");
      return (INIT_FAILED);
   }
   Print("MQTT object created");
   mqtt.setCallback(onreceive);
   EventSetMillisecondTimer(50);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- destroy timer
   EventKillTimer();
   if (mqtt.connected()) {
      mqtt.disconnect();
   }
   Print("MQTT terminated");
   delete (mqtt);
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
time_t lastMessage = 0;

void OnTimer() {
   if (!mqtt.connected()) {
      reconnect();
   } else {
      if (TimeLocal() - lastMessage > 10) {
         lastMessage = TimeLocal();
         string topic = baseTopic + "/last";
         time_t currentTime = TimeLocal();
         MqlDateTime dt;
         TimeToStruct(currentTime,dt);
         string payload = StringFormat("%04d-%02d-%02d %02d:%02d:%02d",dt.year,dt.mon,dt.day,dt.hour,dt.min,dt.sec);
         printf("Publishing message: %s - %s", topic, payload);
         mqtt.publish(topic,payload,true);
      }
   }
   mqtt.loop();
}
//+------------------------------------------------------------------+
