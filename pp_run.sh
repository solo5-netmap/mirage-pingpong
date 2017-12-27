#! /bin/bash

# Parameters (You can change)
APP="pp_udp"
CLIENTADDR="localhost"
SERVERADDR="localhost"
USER="root"
OCAMLVER="4.04.0"

# Parameters (You should not change)
GUEST="Mirage"
BUF="1"
PLATFORM=${1}
BASEDIR=${2}

CLIENTPATH="./${APP}/${APP}_client"
SERVERPATH="./${APP}/${APP}_server"
CLIENTXML="${PLATFORM}_client.xml"
SERVERXML="${PLATFORM}_server.xml"
CLIENTBIN="${APP}_client.${PLATFORM}"
SERVERBIN="${APP}_server.${PLATFORM}"

# Check the arguments provided
case ${PLATFORM} in
        "xen" )
                VIRSH_C="virsh -c xen+ssh://${CLIENTADDR}";
                VIRSH_S="virsh -c xen+ssh://${SERVERADDR}";
        ;;
        "virtio" )
                VIRSH_C="virsh -c qemu+ssh://${CLIENTADDR}/system";
                VIRSH_S="virsh -c qemu+ssh://${SERVERADDR}/system";
        ;;
        * ) echo "Invalid hypervisor selected"; exit
esac

COMPILER="OCaml ${OCAMLVER}"

# switch an OCaml compiler version to be used
opam switch ${OCAMLVER}
eval `opam config env`

# Build and dispatch a server application
cd ./${SERVERPATH}
make clean
mirage configure -t ${PLATFORM}
make
cd ../../

sed -e s@KERNELPATH@${BASEDIR}/${SERVERBIN}@ ./template/${SERVERXML} > ./${SERVERXML}
scp ./${SERVERPATH}/${SERVERBIN} ${USER}@${SERVERADDR}:${BASEDIR}/
SERVERLOG="${OCAMLVER}_${PLATFORM}_${APP}_server.log"
${VIRSH_S} create ./${SERVERXML}

# Dispatch a client side MirageOS VM repeatedly
JSONLOG="./${OCAMLVER}_${PLATFORM}_${APP}.json"
echo -n "{
  \"guest\": \"${GUEST}\",
  \"platform\": \"${PLATFORM}\",
  \"compiler\": \"${COMPILER}\",
  \"records\": [
" > ./${JSONLOG}

CLIENTLOG="${OCAMLVER}_${PLATFORM}_${APP}_client.log"
echo -n '' > ./${CLIENTLOG}

sed -e s@KERNELPATH@${BASEDIR}/${CLIENTBIN}@ ./template/${CLIENTXML} > ./${CLIENTXML}

cd ${CLIENTPATH}
make clean
mirage configure -t ${PLATFORM}
make
cd ../../
scp ./${CLIENTPATH}/${CLIENTBIN} ${USER}@${CLIENTADDR}:${BASEDIR}/
sleep 3

echo -n "{ \"payload\": ${BUF}, \"latency\": [" >> ./${JSONLOG}
echo "***** Testing pingpong: Payload size ${BUF} *****"
${VIRSH_C} create ./${CLIENTXML} --console >> ${CLIENTLOG}
VALUES=`sed -e 's/^M/\n/g' ./${CLIENTLOG} | grep Latency | tail -n 1000 | cut -d' ' -f 8 | tr '\n' ','`
echo -n "${VALUES}" >> ./${JSONLOG}
echo -n "]}," >> ./${JSONLOG}

# Correct the generated JSON file
echo -n "]}" >> ./${JSONLOG}
sed -i -e 's/,\]/]/g' ${JSONLOG}

# Print statistics
cat ./${JSONLOG} | jq

# Destroy the server application
${VIRSH_S} destroy server

