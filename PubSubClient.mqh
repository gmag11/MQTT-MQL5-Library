//+------------------------------------------------------------------+
//| Copyright (c) 2008-2020 Nicholas O'Leary                         |
//|                                                                  |
//| Permission is hereby granted, free of charge, to any person      |
//| obtaining a copy of this software and associated documentation   |
//| files (the "Software"), to deal in the Software without          |
//| restriction, including without limitation the rights to use,     |
//| copy, modify, merge, publish, distribute, sublicense, and/or     |
//| sell copies of the Software, and to permit persons to whom the   |
//| Software is furnished to do so, subject to the following         |
//| conditions:                                                      |
//|                                                                  |
//| The above copyright notice and this permission notice shall be   |
//| included in all copies or substantial portions of the Software.  |
//|                                                                  |
//| THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,  |
//| EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES  |
//| OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND         |
//| NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT      |
//| HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,     |
//| WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING     |
//| FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR    |
//| OTHER DEALINGS IN THE SOFTWARE.                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                 PubSubClient.mqh |
//|                                 Copyright 2023, Nicholas O'Leary |
//|                        https://github.com/knolleary/pubsubclient |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Nicholas O'Leary"
#property link      "https://github.com/knolleary/pubsubclient"
//+------------------------------------------------------------------+
//| defines                                                          |
//+------------------------------------------------------------------+
#ifndef PubSubClient_h
#define PubSubClient_h

//#include <Strings\String.mqh>

//#define MQTT_VERSION_3_1      3
#define MQTT_VERSION_3_1_1    4

// MQTT_VERSION : Pick the version
#ifdef MQTT_VERSION_3_1
#define MQTT_VERSION MQTT_VERSION_3_1
#else
#ifdef MQTT_VERSION_3_1_1
#define MQTT_VERSION MQTT_VERSION_3_1_1
#endif
#endif

// MQTT_MAX_PACKET_SIZE : Maximum packet size. Override with setBufferSize().
#ifndef MQTT_MAX_PACKET_SIZE
#define MQTT_MAX_PACKET_SIZE 1024
#endif

// MQTT_KEEPALIVE : keepAlive interval in Seconds. Override with setKeepAlive()
#ifndef MQTT_KEEPALIVE
#define MQTT_KEEPALIVE 15
#endif

// MQTT_SOCKET_TIMEOUT: socket timeout interval in Seconds. Override with setSocketTimeout()
#ifndef MQTT_SOCKET_TIMEOUT
#define MQTT_SOCKET_TIMEOUT 15
#endif

// Possible values for client.state()
#define OBJECT_CREATION_ERROR      -5
#define MQTT_CONNECTION_TIMEOUT     -4
#define MQTT_CONNECTION_LOST        -3
#define MQTT_CONNECT_FAILED         -2
#define MQTT_DISCONNECTED           -1
#define MQTT_CONNECTED               0
#define MQTT_CONNECT_BAD_PROTOCOL    1
#define MQTT_CONNECT_BAD_CLIENT_ID   2
#define MQTT_CONNECT_UNAVAILABLE     3
#define MQTT_CONNECT_BAD_CREDENTIALS 4
#define MQTT_CONNECT_UNAUTHORIZED    5

#define MQTTCONNECT     1 << 4  // Client request to connect to Server
#define MQTTCONNACK     2 << 4  // Connect Acknowledgment
#define MQTTPUBLISH     3 << 4  // Publish message
#define MQTTPUBACK      4 << 4  // Publish Acknowledgment
#define MQTTPUBREC      5 << 4  // Publish Received (assured delivery part 1)
#define MQTTPUBREL      6 << 4  // Publish Release (assured delivery part 2)
#define MQTTPUBCOMP     7 << 4  // Publish Complete (assured delivery part 3)
#define MQTTSUBSCRIBE   8 << 4  // Client Subscribe request
#define MQTTSUBACK      9 << 4  // Subscribe Acknowledgment
#define MQTTUNSUBSCRIBE 10 << 4 // Client Unsubscribe request
#define MQTTUNSUBACK    11 << 4 // Unsubscribe Acknowledgment
#define MQTTPINGREQ     12 << 4 // PING Request
#define MQTTPINGRESP    13 << 4 // PING Response
#define MQTTDISCONNECT  14 << 4 // Client is Disconnecting
#define MQTTReserved    15 << 4 // Reserved

#define MQTTQOS0        (0 << 1)
#define MQTTQOS1        (1 << 1)
#define MQTTQOS2        (2 << 1)

// Maximum size of fixed header and variable length size header
#define MQTT_MAX_HEADER_SIZE 5

#define uint8_t uchar
#define uint16_t ushort
#define uint32_t uint
#define int32_t int
#define boolean bool
#define size_t ulong
#define time_t datetime

typedef void (*callback)(string& topic, uint8_t& payload[], uint payloadLength);

#define CHECK_STRING_LENGTH(l,s) if (l+2+StringLen(s) > this.bufferSize) {/*SocketClose(_clientSocket);*/return false;}

class PubSubClient {
private:
   int _clientSocket;
   uint8_t buffer[];
   uint16_t  bufferSize;
   uint16_t  keepAlive;
   uint16_t  socketTimeout;
   uint16_t  nextMsgId;
   time_t lastOutActivity;
   time_t lastInActivity;
   bool pingOutstanding;
   callback _callback;
   bool _useTLS;
   
   //uchar ip[4];
   string domain;
   uint16_t port;
   //Stream* stream;
   int _state;
   
   // reads a byte into result
   boolean readByte(uint8_t& result) {
      time_t previousTime = TimeLocal();
      /*while(!SocketIsReadable(_clientSocket)) {
         time_t currentTime = TimeLocal();
         if(currentTime - previousTime >= ((int32_t) this.socketTimeout)){
            printf("Timeout on readByte");
            return false;
         }
      }*/
      uint8_t localBuffer[1];
      int numBytes = 0;
      if (this._useTLS) {
         numBytes = SocketTlsRead(_clientSocket, localBuffer, 1);
      } else {
         numBytes = SocketRead(_clientSocket, localBuffer, 1, this.socketTimeout);
      }
      if (numBytes < 1){
         printf("Error SocketRead. %d received bytes", numBytes);
         return false;
      }
      result = localBuffer[0];
      return true;
   }
   
   // reads a byte into result[*index] and increments index
   boolean readByte(uint8_t& result[], uint16_t& index){
      uint16_t current_index = index;
      uint8_t write_address;
      if(readByte(write_address)){
         result[current_index] = write_address;
         index = current_index + 1;
         return true;
      }
      return false;
   }
   
   string printBuffer (uint8_t& buf[], uint len){
      string result = "";
      for (uint i = 0; i < len; i++) {
         if (buf[i] >= 32 && buf[i] <= 126) {
            result = result + CharToString(buf[i]);
         } else {
            string hex = StringFormat(" 0x%02X ", (uchar)buf[i]);
            result += hex;
         }
      }
      return result;
   }
   
   uint16_t readPacket(uint8_t& lengthLength) {
      uint16_t len = 0;
      if(!readByte(this.buffer, len)) return 0;
      bool isPublish = (this.buffer[0]&0xF0) == MQTTPUBLISH;
      uint32_t multiplier = 1;
      uint32_t length = 0;
      uint8_t digit = 0;
      uint16_t skip = 0;
      uint32_t start = 0;

      do {
         if (len == 5) {
            // Invalid remaining length encoding - kill the connection
            printf ("Invalid length. Len = %d", len);
            _state = MQTT_DISCONNECTED;
            //SocketClose(_clientSocket);
            return 0;
         }
         if(!readByte(digit)) return 0;
         this.buffer[len++] = digit;
         length += (digit & 127) * multiplier;
         multiplier <<=7; //multiplier *= 128
      } while ((digit & 128) != 0);
      lengthLength = (uint8_t)len-1;

      if (isPublish) {
         // Read in topic length to calculate bytes to skip over for Stream writing
         printf("PUBLISH message");
         if(!readByte(this.buffer, len)) return 0;
         if(!readByte(this.buffer, len)) return 0;
         skip = (this.buffer[lengthLength+1]<<8)+this.buffer[lengthLength+2];
         start = 2;
         if ((this.buffer[0] & MQTTQOS1) != 0) {
            // skip message id
            skip += 2;
         }
      }
      //uint32_t idx = len;

      for (uint32_t i = start;i<length;i++) {
         if(!readByte(digit)) return 0;
         /*if (SocketIsWritable(_clientSocket)) { // TODO: Este código es erróneo. Es para stream
            if (isPublish && idx-lengthLength-2>skip) {
               uint8_t localBuffer[1];
               localBuffer[0] = digit;
               SocketSend(_clientSocket, localBuffer, 1);
               //this->stream->write(digit);
            }
         }*/

         if (len < this.bufferSize) {
            this.buffer[len] = digit;
            len++;
         }
         //idx++;
      }

      /*if (!SocketIsWritable(_clientSocket) && idx > this.bufferSize) { // TODO
         len = 0; // This will cause the packet to be ignored.
      }*/
      return len;
   }
   
   // Write string in (pos)th position of the buffer
   uint16_t writeString(string _string, uint8_t& buf[], uint16_t pos) {
      string idp = _string;
      uint16_t i = 0;
      pos += 2;
      while (i < idp.Length()) {
         buf[pos++] = (uchar)StringGetCharacter(idp,i++);
      }
      buf[pos-i-2] = (uchar)(i >> 8);
      buf[pos-i-1] = (uchar)(i & 0xFF);
      return pos;
   }
   
   size_t buildHeader(uint8_t header, uint8_t& buf[], uint16_t length) {
      uint8_t lenBuf[4];
      uint8_t llen = 0;
      uint8_t digit;
      uint8_t pos = 0;
      uint16_t len = length;
      do {
         digit = (uint8_t)(len  & 127); //digit = len %128
         len >>= 7; //len = len / 128
         if (len > 0) {
            digit |= 0x80;
         }
         lenBuf[pos++] = digit;
         llen++;
      } while(len>0);

      buf[4-llen] = header;
      for (int i=0;i<llen;i++) {
         buf[MQTT_MAX_HEADER_SIZE-llen+i] = lenBuf[i];
      }
      return llen+1; // Full header size is variable length bit plus the 1-byte fixed header
   }
   
   boolean write(uint8_t header, uint8_t& buf[], uint16_t length) {
      uint16_t hlen = (uint16_t)buildHeader(header, buf, length);
      uchar sendBuffer[];
      ArrayResize(sendBuffer,length);
      ArrayFill(sendBuffer,0,length,0x66);
      
      ArrayCopy(sendBuffer,buf,0,MQTT_MAX_HEADER_SIZE-hlen,length+hlen);
      
      printf("Header legth: %d Total Length: %d Buffer to send: %s", hlen, length+hlen, printBuffer(sendBuffer,length+hlen));
      
      bool rc = false;
      if (this._useTLS){
         rc = SocketTlsSend(this._clientSocket, sendBuffer, length+hlen);
      } else {
         rc = SocketSend(this._clientSocket, sendBuffer, length+hlen);
      }
      lastOutActivity = TimeLocal();
      return rc;
   }

public:
   PubSubClient() {
      this._state = MQTT_DISCONNECTED;
      this._useTLS = false;
      this._clientSocket = 0;
      //this->stream = NULL;
      this._callback=NULL;
      this.bufferSize = 0;
      setBufferSize(MQTT_MAX_PACKET_SIZE);
      setKeepAlive(MQTT_KEEPALIVE);
      setSocketTimeout(MQTT_SOCKET_TIMEOUT);
   }
   
   PubSubClient(int clientSocket) {
      this._state = MQTT_DISCONNECTED;
      this._useTLS = false;
      setClientSocket(clientSocket);
      //this->stream = NULL;
      this._callback=NULL;
      this.bufferSize = 0;
      setBufferSize(MQTT_MAX_PACKET_SIZE);
      setKeepAlive(MQTT_KEEPALIVE);
      setSocketTimeout(MQTT_SOCKET_TIMEOUT);
   }
   
   PubSubClient(string addr, uint16_t _port, int clientSocket=INVALID_HANDLE) {
      this._state = MQTT_DISCONNECTED;
      this._useTLS = false;
      if (!setServer(addr, _port)) {
         //printf("Set server error. Server %s, port: %d", addr, _port);
         this._state = OBJECT_CREATION_ERROR;
      }
      setClientSocket(clientSocket);
      //this->stream = NULL;
      this._callback=NULL;
      this.bufferSize = 0;
      setBufferSize(MQTT_MAX_PACKET_SIZE);
      setKeepAlive(MQTT_KEEPALIVE);
      setSocketTimeout(MQTT_SOCKET_TIMEOUT);
   }
   
   PubSubClient::PubSubClient(string addr, uint16_t _port, callback callback_f, int clientSocket) {
      this._state = MQTT_DISCONNECTED;
      this._useTLS = false;
      if (!setServer(addr, _port)) {
         this._state = OBJECT_CREATION_ERROR;
      }
      setCallback(callback_f);
      setClientSocket(clientSocket);
      //this->stream = NULL;
      this.bufferSize = 0;
      setBufferSize(MQTT_MAX_PACKET_SIZE);
      setKeepAlive(MQTT_KEEPALIVE);
      setSocketTimeout(MQTT_SOCKET_TIMEOUT);
   }
   
   ~PubSubClient() {
      ArrayFree(this.buffer);
      SocketClose(this._clientSocket);
   }
   
   boolean setBufferSize(uint16_t size) {
      if (size == 0) {
         // Cannot set it back to 0
         return false;
      }
      int result = ArrayResize(this.buffer,size);
      this.bufferSize = size;
      ArrayFill(this.buffer,0,size,0);
      return (result == size);
   }
   
   void setKeepAlive(uint16_t _keepAlive) {
      this.keepAlive = _keepAlive;
   }
   
   void setSocketTimeout(uint16_t timeout) {
      this.socketTimeout = timeout;
   }
   
   void setClientSocket(int clientSocket){
      this._clientSocket = clientSocket;
   }
   
   bool setServer(string _domain, uint16_t _port) {
      if (_domain.Length() == 0) {
         printf("Server address %s is empty", _domain);
         return false;
      }
      this.domain = _domain;
      if (_port == 0){
         printf("Port %d number error", _port);
         return false;
      }
      this.port = _port;
      return true;
   }
   
   void setCallback(callback function) {
      this._callback = function;
   }
   
   boolean PubSubClient::connected() {
      boolean rc;
      if (_clientSocket <= 0 ) {
         rc = false;
      } else {
         rc = SocketIsConnected(_clientSocket);
         if (!rc) {
            if (this._state == MQTT_CONNECTED) {
               this._state = MQTT_CONNECTION_LOST;
               //SocketClose(_clientSocket);
            }
         } else {
            return this._state == MQTT_CONNECTED;
         }
      }
      return rc;
   }
   
   /*boolean connect(string id) {
      return connect(id,"","","",0,false,"");
   }*/

   boolean connect(string id, string user, string pass, bool TLSsocket) {
      return connect(id,user,pass,TLSsocket,"",0,false,"");
   }

   /*boolean connect(string id, string willTopic, uint8_t willQos, boolean willRetain, string willMessage) {
      return connect(id, "", "", willTopic, willQos, willRetain, willMessage);
   }*/

   boolean connect(string id, string user, string pass, bool TLSsocket, string willTopic, uint8_t willQos, boolean willRetain, string willMessage, boolean cleanSession = true) {
      if (!connected()) {
         bool result = false;
         
         if(this._clientSocket > 0 && SocketIsConnected(this._clientSocket)) {
            result = true;
         } else {
            if (this.domain.Length() > 0) {
               if (this._clientSocket == INVALID_HANDLE) {
                  this._clientSocket = SocketCreate();
               }
               if (this._clientSocket == INVALID_HANDLE) {
                  printf("Error creating socket %d: %d", this._clientSocket, GetLastError());
                  return false;
               } else {
                  printf("Socket used: %d", this._clientSocket);
               }
               if (!(result = SocketConnect(this._clientSocket,this.domain,this.port,this.socketTimeout))) {
                  printf("Error al conectar el socket %d: %d", this._clientSocket, GetLastError());
                  return false;
               }
            } else {
               printf("Dominio incorrecto. %s", this.domain);
               return false;
            }
         }
         printf("Socket Conectado. Result %s", result ? "true": "false");
        
         if (TLSsocket) {
            this._useTLS = true;
            if(SocketTlsHandshake(this._clientSocket,this.domain)){
               string   subject,issuer,serial,thumbprint; 
               datetime expiration; 
               //--- if connection is secured by the certificate, display its data 
               if(SocketTlsCertificate(_clientSocket,subject,issuer,serial,thumbprint,expiration)) { 
                  Print("TLS certificate:"); 
                  Print("   Owner:  ",subject); 
                  Print("   Issuer:  ",issuer); 
                  Print("   Number:     ",serial); 
                  Print("   Print: ",thumbprint); 
                  Print("   Expiration: ",expiration); 
               } else {
                  printf("Certificate error");
               }
            } else {
               printf("Error in TLS handshake");
               //SocketClose(this._clientSocket);
               return false;
            }
         }

         if (result) {
            nextMsgId = 1;
            // Leave room in the buffer for header and variable length field
            uint16_t length = MQTT_MAX_HEADER_SIZE;
            //unsigned int j;

#ifdef MQTT_VERSION_3_1
   uint8_t d[9] = {0x00,0x06,'M','Q','I','s','d','p', MQTT_VERSION};
#define MQTT_HEADER_VERSION_LENGTH 9
#else 
#ifdef MQTT_VERSION_3_1_1
            uint8_t d[7] = {0x00,0x04,'M','Q','T','T',MQTT_VERSION};
#define MQTT_HEADER_VERSION_LENGTH 7
#endif
#endif 
            ArrayCopy(this.buffer,d,length,0,MQTT_HEADER_VERSION_LENGTH);
            length += MQTT_HEADER_VERSION_LENGTH;
            printf("----> HEADER: len: %d: buffer: %s", length, printBuffer(this.buffer,length));
            uint8_t v;
            if (willTopic.Length() > 0) {
                v = 0x04|(willQos<<3)|(willRetain<<5);
            } else {
                v = 0x00;
            }
            if (cleanSession) {
                v = v|0x02;
            }

            if(user.Length() > 0) {
                v = v|0x80;

                if(pass.Length() > 0) {
                    v = v|(0x80>>1);
                }
            }
            this.buffer[length++] = v;

            this.buffer[length++] = (uchar)((this.keepAlive) >> 8);
            this.buffer[length++] = (uchar)((this.keepAlive) & 0xFF);

            CHECK_STRING_LENGTH(length,id);
            length = writeString(id,this.buffer,length);
            if (willTopic.Length() > 0) {
                CHECK_STRING_LENGTH(length,willTopic);
                length = writeString(willTopic,this.buffer,length);
                CHECK_STRING_LENGTH(length,willMessage);
                length = writeString(willMessage,this.buffer,length);
            }

            if(user.Length() > 0) {
                CHECK_STRING_LENGTH(length,user);
                length = writeString(user,this.buffer,length);
                if(pass.Length() > 0) {
                    CHECK_STRING_LENGTH(length,pass);
                    length = writeString(pass,this.buffer,length);
                }
            }
            
            printf("----> len: %d: buffer: %s", length, printBuffer(this.buffer,length));
            
            if(!write(MQTTCONNECT,this.buffer,(uint16_t)(length-MQTT_MAX_HEADER_SIZE))) {
               printf("Error after connect");
            }
            
            printf("MQTT connect sent");

            lastInActivity = lastOutActivity = TimeLocal();
            while (!SocketIsReadable(_clientSocket)) {
                time_t t = TimeLocal();
                if ((t-lastInActivity) >= ((int32_t) this.socketTimeout)) {
                    _state = MQTT_CONNECTION_TIMEOUT;
                    //SocketClose(_clientSocket);
                    printf("Socket timeout while trying to connect");
                    return false;
                }
            }
            printf("Socket is readable");
            uint8_t llen;
            uint32_t len = readPacket(llen);
            if (len == 4) {
                if (buffer[3] == 0) {
                    lastInActivity = TimeLocal();
                    pingOutstanding = false;
                    _state = MQTT_CONNECTED;
                    printf("MQTT connect confirmed");
                    return true;
                } else {
                    _state = buffer[3];
                }
            }
            //SocketClose(_clientSocket);
        } else {
            _state = MQTT_CONNECT_FAILED;
        }
        printf ("SocketConnect result is false");
        //SocketClose(_clientSocket);
        return false;
      }
      return true;
   }
   
   boolean publish(string& topic, const uint8_t& payload[], unsigned int plength) {
      return publish(topic, payload, plength, false);
   }
   
   boolean publish(string& topic, const uint8_t& payload[], unsigned int plength, boolean retained = false) {
      if (connected()) {
         if (this.bufferSize < MQTT_MAX_HEADER_SIZE + 2+ topic.Length() + plength) {
            // Too long
            return false;
         }
         // Leave room in the buffer for header and variable length field
         uint16_t length = MQTT_MAX_HEADER_SIZE;
         length = writeString(topic,this.buffer,length);

         // Add payload
         uint16_t i;
         for (i=0;i<plength;i++) {
            this.buffer[length++] = payload[i];
         }

         // Write the header
         uint8_t header = MQTTPUBLISH;
         if (retained) {
            header |= 1;
         }
         return write(header,this.buffer,(uint16_t)(length-MQTT_MAX_HEADER_SIZE));
      }
      return false;
   }
   
   boolean publish(string& topic, string& payload) {
      return publish(topic, payload, false);
   }
   
   boolean publish(string& topic, string& payload, boolean retained) {
      if (connected()) {
         if (this.bufferSize < MQTT_MAX_HEADER_SIZE + 2+ topic.Length() + payload.Length()) {
            // Too long
            return false;
         }
         // Leave room in the buffer for header and variable length field
         uint16_t length = MQTT_MAX_HEADER_SIZE;
         length = writeString(topic,this.buffer,length);

         // Add payload
         uint16_t i;
        
         for (i=0;i<payload.Length();i++) {
            this.buffer[length++] = (uint8_t)StringGetCharacter(payload,i);
         }

         // Write the header
         uint8_t header = MQTTPUBLISH;
         if (retained) {
            header |= 1;
         }
         return write(header,this.buffer,(uint16_t)(length-MQTT_MAX_HEADER_SIZE));
      }
      return false;
   }
   
   boolean subscribe(string& topic) {
      return subscribe(topic, 0);
   }
   
   boolean subscribe(string& topic, uint8_t qos) {
      size_t topicLength = topic.Length();
      if (!StringCompare(topic, "")) {
         return false;
      }
      if (qos > 1) {
         return false;
      }
      if (this.bufferSize < 9 + topicLength) {
         // Too long
         return false;
      }
      if (connected()) {
         // Leave room in the buffer for header and variable length field
         uint16_t length = MQTT_MAX_HEADER_SIZE;
         nextMsgId++;
         if (nextMsgId == 0) {
            nextMsgId = 1;
         }
         this.buffer[length++] = (uint8_t)(nextMsgId >> 8);
         this.buffer[length++] = (uint8_t)(nextMsgId & 0xFF);
         length = writeString(topic, this.buffer, length);
         this.buffer[length++] = qos;
         return write(MQTTSUBSCRIBE|MQTTQOS1,this.buffer,(uint16_t)(length-MQTT_MAX_HEADER_SIZE));
      }
      return false;
   }
   
   boolean unsubscribe(string& topic) {
	   size_t topicLength = topic.Length();
      if (!StringCompare(topic, "")) {
         return false;
      }
      if (this.bufferSize < 9 + topicLength) {
         // Too long
         return false;
      }
      if (connected()) {
         uint16_t length = MQTT_MAX_HEADER_SIZE;
         nextMsgId++;
         if (nextMsgId == 0) {
            nextMsgId = 1;
         }
         this.buffer[length++] = (uint8_t)(nextMsgId >> 8);
         this.buffer[length++] = (uint8_t)(nextMsgId & 0xFF);
         length = writeString(topic, this.buffer,length);
         return write(MQTTUNSUBSCRIBE|MQTTQOS1,this.buffer,(uint16_t)(length-MQTT_MAX_HEADER_SIZE));
      }
      return false;
   }
   
   void disconnect() {
      this.buffer[0] = MQTTDISCONNECT;
      this.buffer[1] = 0;
      if (this._useTLS) {
         SocketTlsSend(_clientSocket,buffer,2);
      } else {
         SocketSend(_clientSocket,buffer,2);
      }
      _state = MQTT_DISCONNECTED;
      //_client->flush();
      SocketClose(_clientSocket);
      lastInActivity = lastOutActivity = TimeLocal();
   }
   
   int state() {
      return this._state;
   }
   
   uint16_t getBufferSize() {
      return this.bufferSize;
   }
   
   boolean loop() {
      if (connected()) {
         time_t t = TimeLocal();
         if ((t - lastInActivity > this.keepAlive) || (t - lastOutActivity > this.keepAlive)) {
            if (pingOutstanding) {
               printf("Timeout error: lastIN %ds lastOUT %ds", t - lastInActivity, t - lastOutActivity);
               this._state = MQTT_CONNECTION_TIMEOUT;
               //SocketClose(_clientSocket);
                return false;
            } else {
               printf("Ping request");
               this.buffer[0] = MQTTPINGREQ;
               this.buffer[1] = 0;
               if (this._useTLS) {
                  SocketTlsSend(_clientSocket,buffer,2);
               } else {
                  SocketSend(_clientSocket,buffer,2);
               }
               lastOutActivity = t;
               lastInActivity = t;
               pingOutstanding = true;
            }
         }
         if (SocketIsReadable(_clientSocket)) {
            uint8_t llen;
            uint16_t len = readPacket(llen);
            uint16_t msgId = 0;
            uint8_t payload[];
            int payloadIdx;
            printf ("Found data. %d bytes", len);
            if (len > 0) {
               lastInActivity = t;
               uint8_t type = this.buffer[0]&0xF0;
               if (type == MQTTPUBLISH) {
                  if (_callback != NULL) {
                     printf("Received PUBLISH, calling callback");
                     uint16_t tl = (this.buffer[llen+1]<<8)+this.buffer[llen+2]; /* topic length in bytes */
                     ArrayCopy(this.buffer,this.buffer,llen+2,llen+3,tl); // TODO: Comprobar si esto funciona
                     //memmove(this->buffer+llen+2,this->buffer+llen+3,tl); /* move topic inside buffer 1 byte to front */
                     this.buffer[llen+2+tl] = 0; /* end the topic as a 'C' string with \x00 */
                     //char *topic = (char*) this->buffer+llen+2;
                     int topicIdx = llen+2;
                     string topic = CharArrayToString(this.buffer, topicIdx, tl);
                     printf("Topic: %s", topic);
                     // msgId only present for QOS>0
                     if ((this.buffer[0]&0x06) == MQTTQOS1) {
                        msgId = (this.buffer[llen+3+tl]<<8)+this.buffer[llen+3+tl+1];
                        payloadIdx = (int)(llen+3+tl+2);
                        int payloadLen = len-llen-3-tl-2;
                        ArrayCopy(payload, this.buffer,0,payloadIdx, payloadLen);
                        _callback(topic, payload, payloadLen);
                        // Send ACK only if PUBLISH is processed in Callback and QOS is 1
                        this.buffer[0] = MQTTPUBACK;
                        this.buffer[1] = 2;
                        this.buffer[2] = (uint8_t)(msgId >> 8);
                        this.buffer[3] = (uint8_t)(msgId & 0xFF);
                        if (this._useTLS) {
                           SocketTlsSend(_clientSocket,this.buffer,4);
                        } else {
                           SocketSend(_clientSocket,this.buffer,4);
                        }
                        lastOutActivity = t;

                     } else {
                        payloadIdx = llen+3+tl;
                        int payloadLen = len-llen-3-tl;
                        ArrayCopy(payload, this.buffer, 0, payloadIdx, payloadLen);
                        _callback(topic, payload, payloadLen);
                     }
                  }
               } else if (type == MQTTPINGREQ) {
                  printf("Received MQTTPINGRESP");
                  this.buffer[0] = MQTTPINGRESP;
                  this.buffer[1] = 0;
                  if (this._useTLS) {
                     SocketTlsSend(_clientSocket,this.buffer,2);
                  } else {
                     SocketSend(_clientSocket,this.buffer,2);
                  }
               } else if (type == MQTTPINGRESP) {
                  printf("Received MQTTPINGRESP");
                  pingOutstanding = false;
               }
            } else if (!connected()) {
               // readPacket has closed the connection
               return false;
            }
         }
         return true;
      }
      return false;
   }
};

#endif // PubSubClient_h
