# covidIsolate

covidIsolate is an open source app, designed to indicate if a subject (user of the app), was in contact with an infectious user of the app.
The goal is to build the app as decentralized and anonymous as possible to prevent abuse, while poviding a secure and reliable platform to the enduser.
Disclaimer: This app is just a prototype and could, due to the lack of resources, not be tested in the real world!

## Technical Concept


### Contact ID encryption vs signing

#### Encryption

![ecnryption concept sketch](Media/concept.jpg)

The encryption of the cId offers more privacy because the encypted cId, which is spread by the Bluetooth beacon, can not be grouped by any attribute and are completely unique. But it would also mean, that every single contact Id(for the last two weeks), of an infected user, would have to be uploaded to a central instance, so other users are able to check on their infection status. This would prohibit discrimination or tracking of users after their public key(privateKey or ID) was leaked or they got infected and their public key is published because their cIds can not be grouped/ identified by their public key or any other attribute.


##### Central infection status check

The central approach for encrypted cIds would require the central instance to not only store, but also to compare the cIds of infected users with all the collected cIds of every user who make their daily infection status check. Which increases the amount of complexity and required infrastructure of the central instance and thus the risk of failure/ outages. It would also decrease the amount of privacy since every user uploads all his cIds for the last x amount of time to the central instance, which could be easilly abused by the cinstance owner.

##### Decentral infection status check

Would require all users to sync massive amounts off data, because every cId(of the last two weeks) of an infectious user would have to be downloaded to all devices, which is not even remotely possible with the current/ average bandwith per user.

### Signing

The signing offers multiple mandatory advantages on the efficiency/ perfomance side, because, the encrypted cIds can be grouped by one public key. Which means that not every cIds of an infected user has to be published(uploaded to a central instance, so other useres can check their infection status), but only their public Key. Sadly, there is a tradeoff in privacy, because once the public key is published, users can be tracked, and potentially discriminated based up on their infection status since signing allows to group signatures by their public keys. 
**This privacy flaw can only be prohibited if every users has at all times the option to change his identity (respectively all his identifiers such as private/public key and ID) and his key pair rotates every x amount of times(Ideally every two weeks, so only two public keys have to be published in the case of an infection, to guarantee a valid two week infection status check).**

##### Central infection status check

The central approach would mean that every user uploads his signed cIds of the last two weeks to a central instance. And the comparison/ infection status check process of the signed cIds with the public keys of infected users, would be done on the central instance. That would require a huge amount of proceccing and complexity, because all public keys would have to be compare with all cIds, which makes the central approach unrealistic and overcomplicated.

##### Decentral infection status check

The decntralized approach would mean that the user downloads all the public keys of infected users and then makes the compraison/ infection status check locally on his device. This would be not only way simpler to realize, because the central instance would **only** serve as storage, which would reduce the risk of failures/ outages dramatically and would mean that the app is far more easier to scale. This approach would also mean that the **privacy of not infectious users is preserved**! Thus every user woul have to sync the (ideally two pKs)public keys of infected users to their device, in order to make the infection status check localy. Since there are a lot infected and not everybody has access to cheap and high bandwith internet, the sync of **new infected users** has to happen on an daily basis, because the number of such is dramatically lower and with that faster to snyc, than to sync all at once.


#### Conclusion/ Final concept

The goal is to find a compromise between privacy, reliability and performance with a focus on privacy while also keeping the reliability factor in mind. To achieve reliability, keeping things simple must be the first priority. This is one of the major advantages of a **decentral infection status check, which is only achievable via. a signature based contact ID**. Taking this route does not come wihtout tradeoffs, which are, as summarized above, that the key pairs must rotate to hinder tracking, etc. but still offers a great level of privacy while maintaining simplicity and scalability.
The only bottleneck being the users internet bandwith, because with new 4000 infected users per day, the size of public keys to download would be round about 8gb.
Apart from that, this concept conclusion applies to all [contact tracing requirements](https://www.ccc.de/en/updates/2020/contact-tracing-requirements), made up by the[ CCC](https://www.ccc.de/).

## Technical realisation
