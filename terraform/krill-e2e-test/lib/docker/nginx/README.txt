The following files were generated:
- certbundle.pem
- krill.key
- rootCA.crt

The commands used to generate them were:

(thanks to Martin Hoffmann for the recipe that these commands were based on)

$ ISSUER="/C=NL/L=Amsterdam/O=NLnet Labs"
$ SUBJECT="/C=NL/L=Amsterdam/O=NLnet Labs/CN=nginx.krill.test"
$ SAN="DNS:nginx.krill.test"
$ openssl req -new \
        -newkey rsa:4096 -keyout issuer.key \
        -x509 -out issuer.crt \
        -days 365 -nodes -subj "$ISSUER"
$ openssl req -new -out subject.csr \
        -newkey rsa:4096 -keyout subject.key \
        -days 365 -nodes -subj "$SUBJECT"
$ echo "subjectAltName=$SAN" > subject.ext
$ openssl x509 \
        -in subject.csr -req -out subject.crt -extfile subject.ext \
        -CA issuer.crt -CAkey issuer.key -CAcreateserial \
        -days 365

$ cp issuer.crt rootCA.crt
$ cp subject.key krill.key
$ cat subject.crt issuer.crt > certbundle.pem

And we also need to do: (see ../relyingparties/base/WARNING.txt for more information)

$ cp rootCA.crt ../relyingparties/base/rootCA.crt

Then clean up:

$ rm issuer.* subject.*