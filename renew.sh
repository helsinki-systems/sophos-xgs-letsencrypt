#! /bin/sh
HOME=/conf/acme
set -x
while :;do
    while IFS=";" read -r certificateFileName listOfAlternativeNames
    do
        if [ -z listOfAlternativeNames ]; then
            echo "missing config parameter"
            exit
        fi
        python3 -m http.server 8000 -d /conf/acme/http &
        pythonPID=$!
        iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination :8000
        certificateNames=$(echo $listOfAlternativeNames | sed "s/,/ -d /g")
        /conf/acme/acme.sh \
        -w /conf/acme/http/ --issue --server letsencrypt --reloadcmd "killall -SIGHUP httpd" \
        --cert-file      /conf/certificate/$certificateFileName.pem \
        --key-file       /conf/certificate/private/$certificateFileName.key \
        -d $certificateNames

        # clean up redirect rule
        linenumber="$(iptables -t nat -L PREROUTING -n -v --line-numbers | grep "tcp dpt:80 to::8000" | cut -d " " -f1)"
        iptables -t nat -D PREROUTING "$linenumber"
        # reload httpd server to use new cert
        kill -9 $pythonPID
        killall -SIGHUP httpd
        # all done

    done < /conf/acme/config.csv
    sleep 86400 # run every day
done
