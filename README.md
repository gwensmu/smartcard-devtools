# Setting up your own private key infrastructure (PKI) for developing smartcard authorization

## What is Mutual TLS?

Most web devs are familiar with HTTPS - HTTP over TLS. HTTPS is generally one-way TLs -> the client (often a web browser) makes a request to a web server on a secure port (often 443) to initiate a secure connection. During the following negotation between the server and the client, the server presents a public server certificate, signed by a certificate authority (CA) that the client trusts.

These certificate authorites are usually big names like Let's Encrypt, Amazon, GlobalSign, VeriSign. The client will typically look to the host operating system to determine which CAs are trustworthy. Here's the full list of CAs that OSX High Sierra trusts by default: https://support.apple.com/en-us/HT208127

If the server certificate is trustworthy, the client will proceed forward with the dance. This is my favorite explanation for those who want to dig into all the steps:

https://tls.ulfheim.net/

Trust is configurable. If you decide that your system should trust a CA not in the operating system defaults, and you have sysadmin rights for the system, you can tell it to trust additional certificate authorities, such as one operated by your own organization. Banks do this, and so do militaries. One reason to run your own PKI is to cut costs, by cutting out the middleman. Another is to reduce attack surface, by cutting out the middleman.

Something you really do not want when you are operating a bank, for example, is for a certificate authority provisioning you certificates that say "yes, this webserver is owned and operated by BigMonday Bank" to also then go ahead and hand out (accidently or not) certificates with your name on them to sysadmins who are NOT associated with your bank. This is the WORST CASE SCENARIO but it also happens:

https://cybersheath.com/what-to-learn-from-a-bank-hack-in-brazil/

For similar reasons, developers don't always have access to certificates signed by the CA that will be used in production. When they want to test their TLS configuration, they will use PKI to sign certificates themselves, and configure the systems hosting their dev servers to trust these certs when the system is running in development mode. Browsers now ship with various safeguards to prevent their users from interacting with self-signed certificates, but you can turn these off, which is helpful when testing.

So. That's the one-way TLS story. You're the operator of a website, you want the users of your website to trust it (via their OS trust configuration), and then once this trust is established, your users and your website will pass sensitive information back and forth via TLS. Why is it one-way? Because the client demands that the server prove who it is, but the server (during the TLS negotiation) does not require the client to prove anything about itself.

Mutual TLS adds a step: not only must the server present proof of identity to the client ("yes, I am owned and operated by BigMonday Bank, I will not steal your password and hand it to criminals"), but the client must provide proof of identity to the server, by providing the server a certificate signed by a CA that the server is configured to trust.

For end users, Mutual TLS is often called MFA or Smartcard Auth. End users carry the certificate around on a smartcard (something they have), which can be unlocked with a PIN (something they know). Think about withdrawing money from an ATM. How do you prove to the ATM that you own the account you are accessing? How does the bank prevent forgery of ATM cards? You put a card with a chip in it into the machine, and then type in your PIN. The PIN decrypts your personal client certificate stored on the ATM card, and the ATM checks that it's a valid, trustworthy cert.

Webservers can be configured to do Mutual TLS. Server side, this is typically called client verification.

If, as a developer, you are tasked with developing a system that performs mutual TLS, you won't always have access to certificate signed by CA that will be used in production. There are various reasons for this, such as bureacracy, or separation of duties concerns (IMO developers get trusted with production certs way more often then they should). If you're in that situation, never fear! In development, you can self-sign the client certs too. Here's how to do it:
## Quick Reference

```bash
# do this once - setup CA
make create_ca
make root_cert

# do this for each client/user who needs a cert
make private_key
make csr
make crt
make bundle

# do this for certificate revocation
make crl
make revoke_crt
```
## Narrative Version

Note: in real life systems, most of the steps below are performed automatically by computers and scripts, not manually. I'm describing them as steps performed people because like many humans, connect more to stories about people.

First, we'll create a certificate authority. In a large organization, this would be the responsiblity of an ops team with
lots of security chops. They'll need those chops to keep the CA files secure. Creating them is easy!

While you execute the following commands, imagine that you are a DevSecOps engineer named Amira. If this CA will be used on any sites hosted on the WWW (eg, a staging site) you should set a strong password and treat all keys as sensitive.

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

You have just generated a root key. Save that passphrase in a secure place. Keep your root key in a safe place too. This key will be used to create your root certificate. Anyone who has the root key and its password has the ability to generate client certificates your site will trust.

``` bash
$ make root_cert
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

First, we want to generate a private key, unique for our new employee. You do this:

```
$ make private_key
openssl genrsa -out dev.key 2048
Generating RSA private key, 2048 bit long modulus (2 primes)
..+++++
.................+++++
e is 65537 (0x010001)
```

Then you generate a certificate signing request. The CSR will use the key you just made to create a file that allows Amira to create a certificate that will be uniquely associated with the new employee sitting in front of you. The certificate that Amira gives you will store some metadata about the new employee, like their name, that's defined below.

``` bash
$ make csr
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

You, Jose, send the CSR to Amira. You've worked with Amira for many years, so while she didn't check the new employees driver's licence herself, she trusts that you did. She uses the CSR, the CA, and the password to the root key to generate a signed certificate for your new employee. Amira also sets a password on the private key. (In real life, where scripts are doing most of this, the end user may set their password.) Then, she creates a bundle, bundling the cert and the key together. Then she sends the bundle back with the password to Jose.

``` bash
$ make crt
openssl x509 -req -in dev.csr -CA ca.pem -CAkey ca.key -CAcreateserial -out dev.crt -days 825 -sha256 -extfile config.ext
Signature ok
subject=C = US, ST = IL, L = Chicago, O = Tandem, OU = Tandem, CN = Gwen Smuda, emailAddress = gwen.smuda@gmail.com
Getting CA Private Key
Enter pass phrase for ca.key:
```

```bash
$ make bundle
openssl pkcs12 -export -in dev.crt -inkey dev.key -out client.p12 -name "clientcert"
Enter Export Password:
Verifying - Enter Export Password:
```

Now both you and Jose both know the bundle password for the new employee. That's not good, that breaks non-repudiation. You really don't want to be associated with this new employee's activities in any way, in case they commit crimes and accuse you of stealing their keycard to do them. While sitting with the new employee, you have them change the bundle password to one that only they know via a little number keyboard. Only after they've typed it will you let them know that the PIN is very important and they shouldn't forget it. You, Jose, also find your job somewhat bureaucratic and are unimpressed with the lack of espionage.

You (Jose) store the bundle on the smartcard using some magic. Then you give the smartcard to the new employee, and remind them that they shouldn't forget their PIN, but also they should not write it down anywhere. After they leave, you realize you forgot their name, so you inspect the cert, cuz it says all sorts of things about them, like their common name, and where they work:

``` bash
$ openssl x509 -in dev.crt -text -noout
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            ...
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: C = US, ST = IL, L = Chicago, O = Tandem, OU = Tandem, CN = Gwen Smuda, emailAddress = gwen.smuda@gmail.com
        Validity
            Not Before: Jan  7 22:40:42 2021 GMT
            Not After : Apr 12 22:40:42 2023 GMT
        Subject: C = US, ST = IL, L = Chicago, O = Tandem, OU = Tandem, CN = Gwen Smuda, emailAddress = gwen.smuda@gmail.com
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
        ...
        X509v3 extensions:
            X509v3 Authority Key Identifier:
                keyid:...
            X509v3 Basic Constraints:
                CA:FALSE
            X509v3 Key Usage:
                Digital Signature, Non Repudiation, Key Encipherment, Data Encipherment
            X509v3 Subject Alternative Name:
                DNS:dev
    Signature Algorithm: sha256WithRSAEncryption
    ...
```

Now you are Amira again. You're meditating on your life and your choices when you realize that you've been provisioning all these certs, but
you have no way of revoking them. Before anyone else notices, you create a certificate revocation list:

```
$ make crl
openssl ca -config ca.conf -gencrl -keyfile ca.key -cert ca.pem -out ca.crl.pem && openssl crl -inform PEM -in ca.crl.pem -outform DER -out ca.crl
Using configuration from ca.conf
Enter pass phrase for ca.key:
```

Now it is Tuesday of next week. You are Jose. HR just told you that the new employee has already quit. You call Amira to let her know. "Yes," says Amira, "I am fully prepared for this and have been for some time."

You are Amira. You revoke the certificate.

```bash
make revoke_crt
```

In this example, certificate revocation checks are handled by a CRL file which is loaded onto the server. In practice, these lists get big, so you'll use OSCP instead, which is a HTTP request to a web endpoint on port 80 that will check the revocation list. The OSCP endpoint will be listed on the client cert if its being used as part of the PKI scheme. The SSL library running on the webserver will know how to do this, you just tell it where to go, or if it should use the info on the cert.

```bash
make crl
```

Now, if the former employee breaks into the office and tries to use the bathroom, they will be unable to access the toilet. They will swipe their smartcard (which HR should have collected, but you know HR) and the bathroom server will check the expiration date (still good) and the certificate revocation list and see that the cert is no good around here anymore.

Congrats! That was the full lifecycle of authentication via PKI!

## Server Configuration

But wait, you say! This is all well and good, but how do I configure my webserver to do Mutual TLS? Great question! It's not the default setting!

Let's say your webserver is Apache. Here is a Very Minimal vhost configuration with only the parts related to TLS:

```
<VirtualHost *:443>
    ...

    SSLCertificateFile "/usr/local/apache2/ssl/certs/server.crt"
    SSLCertificateKeyFile "/usr/local/apache2/ssl/certs/server.key"
    
    # Enable client verification
    SSLVerifyClient require

    # A list of public certs for certificate authories that you trust.
    # In this case, "trust" means: they are used to provision client certs 
    # for your users.
    SSLCACertificateFile /etc/httpd/ssl/certs/trusted_certificate_authorities.pem
    
    # Enables certificate revocation checks
    # Server will need to be able to access ocsp.yourorg.internet on port 80
    SSLOCSPEnable on
    SSLOCSPDefaultResponder http://ocsp.yourorg.internet

    # If you are running as a reverse proxy,
    # Uses mod_ssl to extract ID metadata and pass it to the backend
    # via a request header
    # The full list of variables available on the cert are here: 
    # https://httpd.apache.org/docs/current/mod/mod_ssl.html#page-header
    RequestHeader set X-USERNAME "%{SSL_CLIENT_S_DN_CN}s"
    
    ...
</VirtualHost>
```

If you're in the Rails universe, you might be interested in rails-auth. https://github.com/square/rails-auth/wiki/X.509

For Spring Boot Fans: https://www.baeldung.com/x-509-authentication-in-spring-security

