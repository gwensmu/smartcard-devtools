create_ca:
	openssl genrsa -des3 -out ca.key 2048

generate_root_cert:
	openssl req -x509 -new -nodes -key ca.key -sha256 -days 1825 -out ca.pem

generate_private_key:
	openssl genrsa -out dev.key 2048

generate_csr:
	openssl req -new -key dev.key -out dev.csr

generate_crt:
	openssl x509 -req -in dev.csr -CA ca.pem -CAkey ca.key -CAcreateserial -out dev.crt -days 825 -sha256

generate_keystore:
	openssl pkcs12 -export -in dev.crt -inkey dev.key -out client.p12 -name "clientcert"

create_crl:
	openssl ca -config ca.conf -gencrl -keyfile ca.key -cert ca.pem -out ca.crl.pem && openssl crl -inform PEM -in ca.crl.pem -outform DER -out ca.crl

revoke_crt:
	openssl ca -config ca.conf -revoke dev.crt -keyfile ca.key -cert ca.crt

# todo: this isn't right
regenerate_crl:
	create_crl