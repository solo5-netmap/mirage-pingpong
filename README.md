# Network pingpong like tool for MirageOS

## Directory
`pp`: TCP-based pingpong server/client  
`pp_udp`: UDP-based pingpong server/client  
(Both can generate output result of 1,000 repeated latency measurement on stdout)

## Script
(For single server/client pair execution)  
`pp_run.sh`: for xen and virtio using the `virsh` command  

## Usage
`pp_run.sh`  
1. Modify IP setting in  `./{pp,pp_udp}/{pp,pp_udp}_{client,server}/config.ml` so that your unikernel can run on your network environment
2. Set a value for each variable in the script:  
`APP`: pp or pp_udp  
`CLIENTADDR`: IP address of a pp-client side machine  
`SERVERADDR`: IP address of a pp-server side machine  
`USER`: username for ssh and scp on the pp-client/server machines  
`OCAMLVER`: OCaml version used for `opam switch` in the script  
3. Configure your ssh login so that your passphrase is not required for the pp-client/server side machines (maybe by using `ssh-agent` and `ssh-add`)
4. Execute the script with two arguments like `./pp_run.sh virtio /tmp`  
1st argument: target platform, `virtio` or `xen`  
2nd argument: directory to which your unikernel binary is sent by scp  
