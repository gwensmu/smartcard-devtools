# Setting up your own private key infrastructure (PKI) for developing smartcard authorization

If you're newer to key management, please consult with your org's security professional before using this
tooling on any staging/test sites.

First, we'll create a certificate authority. In a large organization, this would be the responsiblity of an ops team with
lots of security chops. They'll need those chops to keep the CA files secure. Creating them is easy!

While you execute the following commands, imagine that you are a DevSecOps engineer named Amira. You don't have to set the passphrase, but its a good habit. If this CA will be used on any sites hosted on the WWW (eg, a staging site) you should set a password and treat all keys as sensitive.

``` bash
$ make create_ca
openssl genrsa -des3 -out ca.key 2048
Generating RSA private key, 2048 bit long modulus (2 primes)
....+++++
................+++++
e is 65537 (0x010001)
Enter pass phrase for ca.key:
Verifying - Enter pass phrase for ca.key:
```

You have just generated a root key, and hopefully associated a password with it. Save that passphrase in a secure place. Keep your root key secure. This key will be used to create your root certificate. Anyone who has the root key and its password has the ability to generate certificates your site will trust.

``` bash
$ make generate_root_cert 
openssl req -x509 -new -nodes -key ca.key -sha256 -days 1825 -out ca.pem
Enter pass phrase for ca.key:
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Country Name (2 letter code) [AU]:US      
State or Province Name (full name) [Some-State]:IL
Locality Name (eg, city) []:Chicago
Organization Name (eg, company) [Internet Widgits Pty Ltd]:Tandem
Organizational Unit Name (eg, section) []:Tandem
Common Name (e.g. server FQDN or YOUR name) []:Gwen Smuda
Email Address []:gwen.smuda@gmail.com
```

Now you have a root certificate. It is called the "root" because when combined with your root key, it can be used to sign certificates.

The root cert is public. If you want to set up a server to do client verification, you'll add this root cert to the list of certificate authorities that your server will accept. When a client presents a cert, it has to be signed by one of these CAs to be accepted.

Ok, you've been imagining yourself as Amira, right? CISSP, Masters degree in CS from Stanford, wondering how her security career turned out to be so bureaucratic? Stop doing that. Your name is now Jose, and you are a sysadmin onboarding a new employee at your Chicago office. You're provisioning their smartcard so they can use the office bathroom. The new employee has already provided you with a drivers licence, and after thirty tense minutes of debate, convinced you that they are who they say they are.

First, we want to generate a private key. This will be stored on the smartcard. It will be encrypted - the only way to decrypt it is for the owner of the smartcard to type in their pin. (todo, is that true?) You do this:

```
$ make generate_private_key
openssl genrsa -out dev.key 2048
Generating RSA private key, 2048 bit long modulus (2 primes)
..+++++
.................+++++
e is 65537 (0x010001)
```

Then you generate a certificate signing request. The CSR will use the key you just made to create a file that allows Amira to create a certificate that will be uniquely associated with the new employee sitting in front of you. The certificate that Amira gives you will store some metadata about the new employee, like their name, that's defined below.

``` bash
$ make generate_csr
openssl req -new -key dev.key -out dev.csr
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Country Name (2 letter code) [AU]:US
State or Province Name (full name) [Some-State]:IL
Locality Name (eg, city) []:Chicago
Organization Name (eg, company) [Internet Widgits Pty Ltd]:Tandem
Organizational Unit Name (eg, section) []:Tandem
Common Name (e.g. server FQDN or YOUR name) []:Gwen Smuda
Email Address []:gwen.smuda@gmail.com

Please enter the following 'extra' attributes
to be sent with your certificate request
A challenge password []:
An optional company name []:
```

You, Jose, send the CSR to Amira. You've worked with Amira for many years, so while she didn't check the new employees driver's licence herself, she trusts that you did. She uses the CSR, the CA, and the password to the root key to generate a signed certificate for your new employee, and sends the certificate back.

``` bash
$ make generate_crt
openssl x509 -req -in dev.csr -CA ca.pem -CAkey ca.key -CAcreateserial -out dev.crt -days 825 -sha256 -extfile config.ext
Signature ok
subject=C = US, ST = IL, L = Chicago, O = Tandem, OU = Tandem, CN = Gwen Smuda, emailAddress = gwen.smuda@gmail.com
Getting CA Private Key
Enter pass phrase for ca.key:
```

```bash
$ make generate_keystore
openssl pkcs12 -export -in dev.crt -inkey dev.key -out client.p12 -name "clientcert"
Enter Export Password:
Verifying - Enter Export Password:
```

When we get to the "export password" step, you, Jose, will hand the keyboard to the new employee and ask them to type a pin. Only after they've typed it will you let them know that the pin is very important and they shouldn't forget it. You, Jose, also find your job somewhat bureaucratic and are unimpressed with the lack of espionage.

You (Jose) store the keystore on the smartcard using some magic. Then you give the smartcard to the new employee, and remind them that they shouldn't forget their pin, but also they should not write it down anywhere. After they leave, you realize you forgot their name, so you inspect the cert, cuz it says all sorts of things about them:

``` bash
$ openssl x509 -in dev.crt -text -noout
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            68:98:d5:ec:ca:7e:5a:bd:3b:48:ca:3a:09:36:ec:af:81:f5:ee:1a
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: C = US, ST = IL, L = Chicago, O = Tandem, OU = Tandem, CN = Gwen Smuda, emailAddress = gwen.smuda@gmail.com
        Validity
            Not Before: Jan  7 22:40:42 2021 GMT
            Not After : Apr 12 22:40:42 2023 GMT
        Subject: C = US, ST = IL, L = Chicago, O = Tandem, OU = Tandem, CN = Gwen Smuda, emailAddress = gwen.smuda@gmail.com
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                RSA Public-Key: (2048 bit)
                Modulus:
                    00:be:7f:03:c9:5c:4e:78:05:41:4a:a6:3a:8b:bc:
                    e7:e8:94:33:36:90:5f:07:0e:6f:49:8c:e9:46:d6:
                    4e:4b:08:ce:f6:8e:9d:ae:0d:5d:07:e9:94:52:dd:
                    1e:31:f2:c7:c6:53:f1:5b:b5:8b:16:45:e3:7b:18:
                    05:2b:bd:20:ff:be:56:4f:aa:0a:42:85:7b:5d:ca:
                    46:bd:2c:18:65:86:d5:28:26:8d:31:e9:a1:7e:cb:
                    a3:bd:8a:a1:80:cb:75:0e:84:e2:22:ae:da:4b:ed:
                    e5:ee:14:b9:ad:05:1f:fd:8d:34:3d:fd:d6:c1:fe:
                    9e:75:68:92:62:f1:23:81:ff:d5:62:de:7a:ac:68:
                    41:e4:d0:2a:b3:ff:2d:1d:6f:4c:33:fc:ae:73:30:
                    dd:ba:07:72:79:b2:6e:31:e3:44:c2:53:37:7f:64:
                    c2:84:08:cf:7a:14:68:aa:9f:3a:38:9e:9b:e9:61:
                    74:56:7b:6e:10:f0:71:bf:cc:5a:3e:8c:b5:fc:e0:
                    ea:f9:67:26:11:b7:ee:af:71:ec:00:69:86:a8:83:
                    ff:19:8a:10:9c:c3:0f:95:d7:24:3d:fd:66:a2:f1:
                    c0:5d:ca:62:d3:f3:91:17:30:66:ef:5e:4b:87:c7:
                    df:0d:8e:8f:e7:5c:59:bb:64:c3:49:4e:db:68:9c:
                    f8:ed
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Authority Key Identifier: 
                keyid:82:D5:9C:B9:72:8E:D2:B0:79:29:4E:09:67:A1:2D:3B:C8:09:92:1D

            X509v3 Basic Constraints: 
                CA:FALSE
            X509v3 Key Usage: 
                Digital Signature, Non Repudiation, Key Encipherment, Data Encipherment
            X509v3 Subject Alternative Name: 
                DNS:dev
    Signature Algorithm: sha256WithRSAEncryption
         04:7c:97:14:8f:ef:28:6d:8f:e1:9d:ae:96:78:c1:9e:7a:3f:
         f4:86:4c:1f:33:14:17:ae:6b:07:2e:50:48:12:3e:53:1b:06:
         52:fa:b2:d6:fe:45:ba:6a:64:0c:8d:78:fa:1d:46:28:a0:07:
         34:af:05:b3:59:e7:78:8c:3a:86:21:b4:f3:ca:c5:26:4b:7b:
         bd:9f:71:c6:38:74:ef:63:9b:5d:ae:de:7b:40:af:9f:05:38:
         1d:ce:c5:6e:68:81:e5:c7:15:b3:5d:63:a5:18:a0:7c:27:63:
         b4:14:7a:6f:74:6d:87:01:ee:5b:39:25:c9:8b:e7:e6:ba:79:
         b4:3d:da:a4:d1:24:14:1b:d2:04:fd:df:e7:c4:a8:41:b5:f1:
         a2:7a:85:0e:cd:f9:b3:98:bd:2e:36:e9:7a:f5:9e:ca:38:35:
         30:2d:44:32:70:75:74:1c:0e:33:95:60:7a:21:5d:ca:5b:b5:
         db:cc:73:72:ae:52:75:f6:21:ec:87:f9:83:44:41:65:fe:3d:
         93:33:1e:3f:25:4d:1d:74:b4:3e:e5:a4:38:6d:eb:0f:8d:f5:
         1e:96:9d:70:a1:02:a4:3a:60:3c:24:23:c7:fa:a3:9f:da:de:
         fc:d3:62:0a:9e:73:d3:71:65:56:97:68:bf:65:58:38:ff:47:
         40:e1:08:fb
```

Now you are Amira again. You're meditating on your life and your choices when you realize that you've been provisioning all these certs, but 
you have no way of revoking them. Before anyone else notices, you create a certificate revocation list:

```
$ make create_crl
openssl ca -config ca.conf -gencrl -keyfile ca.key -cert ca.pem -out ca.crl.pem && openssl crl -inform PEM -in ca.crl.pem -outform DER -out ca.crl
Using configuration from ca.conf
Enter pass phrase for ca.key:
```

Now it is Tuesday of next week. You are Jose. HR just told you that the new employee has already quit. You call Amira to let her know. "Yes," says Amira, "I am fully prepared for this and have been for some time." 

You are Amira. You revoke the certificate.

```bash
make revoke_crt 
```

In this example, certificate revocation checks are handled by a CRL file which is loaded onto the server. In practice, these lists get big, so you'll use OSCP instead, which is just a http request over 80 to a web endpoint that will check the revocation list. The OSCP endpoint will be listed on the client cert if its being used as part of the PKI scheme.

```bash
make regenerate_crl
```

Now, if the former employee breaks into the office tries to use the bathroom, they will be unable to access the toilet. They will swipe their smartcard (which HR should have collected, but you know HR) and the bathroom server will check the expiration date (still good) and the certificate revocation list and see that the cert is no good around here anymore.

Congrats! That was the full lifecycle of authentication via PKI!