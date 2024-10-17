# Raspberry Pi automated nest box monitoring system

Camera-based surveillance is a non-invasive method for collecting data on many taxa of animals (reviewed by Reif & Tornberg 2006; Trolliet et al. 2014). Camera technologies are most often used for monitoring the trends over time and space(e.g. regory et al. 2014), their activity patterns (e.g. Gray & Phan 2011), behaviour and feeding ecology (e.g. Miller, Carlisle & Bechard 2014), or for the identification of nest predators (e.g. DeGregorio, Weatherhead & Sperry 2014). 

The Raspberry Pi (hereafter RPi) is a reliable, low-cost (~ EU 45€) micro-computer developed in 2006 by the University of Cambridge’s Computer Department, and produced by the Raspberry Pi Foundation in 2012 as a tool to encourage students to learn programming language (Severance 2013). This credit card-sized micro-computer boots to a programming environment that allows users to customize their RPi using Python programming language and uses the UNIX/debian-based Raspbian operating system, a free operating system optimized for RPi hardware. One of the foremost uses of the Raspberry Pi is as a low-cost image and (HD) video recording device (Jolles, 2021). 

In this project we explain in detail how we developed a **solar powered automated recording system for multiple nest-boxes at once**, using the RPi technology. The system has been monitoring a jackdaw colony which breed in artificial nest boxes in a breeding tower since 2022 (see picture below). Every nest box has been monitored with an IR camera with night vision and a temperature sensor, working 24h a day. 

![Breeding tower, experimental setup](https://github.com/mpourossell/RaspberryPi-automated-smart-nestbox/blob/master/images/outdoor%20picture.jpg)

![Nest construction behaviour in jackdaws](https://github.com/mpourossell/RaspberryPi-automated-smart-nestbox/blob/master/images/indoor%20picture.jpg)

## System schematics

The system is composed by 2 different subsystems:

1. Indoor system

The system inside the breeding tower is used to record the nest boxes from the inside, with a *master RPi* controlling several *children RPis*. 
It is composed by a **solar panel**, which powers a **car battery** using a **solar controller**, which power goes to a **relay board** and to the **master RPi**. The master RPi controls the relay board and opens or closes the circuit between the battery and each of the **children RPi** using the GPIO pins.

Every RPi goes to a single nest box. All RPis are composed by a **Raspberry Pi Zero 2W**, a **wide angle camera**, an **IR LED** to allow night vision, a **temperature sensor** and a **RTC**. 

To allow remote connection and to report errors, all RPis are connected to the internet provided by a **4G USB wingle**, that is connected directly to the USB port from the solar controller.

![Hardware schematics of the indoor system](https://github.com/mpourossell/RaspberryPi-automated-smart-nestbox/blob/master/images/indoor%20scheme.png)

2. Outdoor system

This system is used to record the breeding tower from the outside, in order to monitor what birds do at the entries of the nest boxes.
It is composed by a **solar panel**, which powers a **3,7V battery** using the **PiJuice HAT** module, connected to a **Raspberry Pi Zero 2W**. As this system is 10m away from the nests, it is using the **HQ camera module** and a **8-55mm zoom lens** that can be easily modified to get the desired focal length depending on the distance it is placed.

![Hardware schematics of the outdoor system](https://github.com/mpourossell/RaspberryPi-automated-smart-nestbox/blob/master/images/outdoor%20scheme.png)


