create_ca:
	openssl genrsa -des3 -out outputs/ca.key 2048

root_cert:
	openssl req -x509 -new -nodes -key outputs/ca.key -sha256 -days 1825 -out outputs/ca.pem

private_key:
	openssl genrsa -out outputs/dev.key 2048

csr:
	openssl req -new -key outputs/dev.key -out outputs/dev.csr

crt:
	openssl x509 -req -in outputs/dev.csr -CA outputs/ca.pem -CAkey outputs/ca.key -CAcreateserial -out outputs/dev.crt -days 825 -sha256

bundle:
	openssl pkcs12 -export -in outputs/dev.crt -inkey outputs/dev.key -out outputs/client.p12 -name "clientcert"

crl:
	openssl ca -config ca.conf -gencrl -keyfile outputs/ca.key -cert outputs/ca.pem -out outputs/ca.crl.pem && openssl crl -inform PEM -in outputs/ca.crl.pem -outform DER -out outputs/ca.crl

revoke_crt:
	openssl ca -config ca.conf -revoke outputs/dev.crt -keyfile outputs/ca.key -cert outputs/ca.crt
