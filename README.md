# Beacon

![](https://challengepost-s3-challengepost.netdna-ssl.com/photos/production/software_photos/001/363/639/datas/original.png)

https://devpost.com/software/beacon-jybrxm

## Inspiration

During emergencies and natural disasters, internet and phone connectivity can often be lost, leaving people unable to contact loved ones or call for assistance. 

Our goal was to make a messaging app that allows you to get messages to loved ones even when internet connectivity is completely lost, and broadcast requests for help to those in the vicinity (such as emergency services).

By its decentralized, encrypted nature, this is also a tool for protecting privacy and allow communication in countries where the internet is severely limited or monitored.

## What it does

Beacon is a fully-fledged messaging app with **zero servers**, that:
- doesn't need an internet connection, even for setup
- builds its own mesh network of nearby devices through Bluetooth, and communicates by routing messages through this network
- Lets you send messages to anyone in the network, even if they're not nearby
- Encrypts messages with **end-to-end encryption**
- Allows you to broadcast messages for help to 
everyone nearby
- Allows you to send locations. This is particularly useful in disaster scenarios.
- Allows you to send photos (unstable, and very limited)

## How we built it

We use Bluetooth & ultrasound to detect nearby devices running Beacon up to 100m away and connect to them. When devices join the network, anyone can send them a message

### Physical Mesh Layer

The physical mesh layer uses Bluetooth and ultrasound to detect nearby devices. Each device
has two services: advertising and discovery. We use the services to establish the mesh network.

One of the challenges we ran into was the limit on the number of devices connected to a given device, we discovered that a device may approximately connect to at *most* 4 other devices, otherwise the connections are no-longer stable. To address this we designed a custom algorithm to optimize mesh connectivity while maintaining network stability. 

### Message Layer

The message layer uses the physical mesh layer, forming a custom network stack, to implement
a simple gossip protocol that ensures messages reach their intended recipient. Acknowledgment responses allow users to see whether messages have been delivered. Buffers are used to ensure that network partitions don't necessarily prevent messages from being sent (once the partition is healed). 

### Encryption Layer

The encryption layer uses the message layer to provide end-to-end RSA 2048 encryption within the application. Ensuring that users may privately message each other without privacy concerns. 
Key sharing is performed manually, using QR codes.


## Challenges we ran into

We found out that Bluetooth can be very unstable when connecting to multiple devices, so a lot of our time was spent into trying to make this more resilient.

## Accomplishments that we're proud of

- Designing a custom protocol for maximizing the stability of a Bluetooth mesh network while maximizing connectivity and reach.
- Building our own routing protocol to send messages between devices that can't see each other
- Implementing our own end-to-end encryption layer

## What we learned

Most of us had never used Flutter, and none of us had worked with Bluetooth or networking before, making this a steep learning curve! :)

## What's next for Beacon

- Field testing with a larger mesh network
- Improving our protocols

