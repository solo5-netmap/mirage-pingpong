open Lwt.Infix

module Main (S: Mirage_types_lwt.STACKV4) = struct

   let return_ip = Ipaddr.V4.of_string_exn "192.168.122.101"
   let port = 7001

   let msg = "0"
   let mlen = String.length msg
   let a = Cstruct.sub (Io_page.(to_cstruct (get 1))) 0 mlen

   let err_connect ip port () =
     let ip  = Ipaddr.V4.to_string ip in
     Logs.info (fun f -> f "Unable to connect to %s:%d" ip port);
     Lwt.return_unit

   let err_write () =
     Logs.info (fun f -> f "Error while writing to TCP flow.");
     Lwt.return_unit

   let write_and_check flow buf =
     (*Logs.info (fun f -> f "Writing.");*)
     S.TCPV4.write flow buf >|= Rresult.R.get_ok

   let receiver flow =
     let rec pingpong_h flow =
       S.TCPV4.read flow >|= Rresult.R.get_ok >>= function
       | `Eof ->
         Logs.info (fun f -> f  "pingpong server: connection closed.");
         Lwt.return_unit
       | `Data _ ->
         begin
           (*Logs.info (fun f -> f  "pingpong server: connected.");*)
           write_and_check flow a >>= fun () ->
           (*Logs.info (fun f -> f  "pingpong server: Done - responded.");*)
           pingpong_h flow
         end
     in
     pingpong_h flow

  let start s =
    let ips = List.map Ipaddr.V4.to_string (S.IPV4.get_ip (S.ipv4 s)) in
    Logs.info (fun f -> f "pingpong server process started:");
    Logs.info (fun f -> f "IP address: %s" (String.concat "," ips));
    Logs.info (fun f -> f "Port number: %d" port);

    S.listen_tcpv4 s ~port:port (fun flow ->
      receiver flow
    );
    S.listen s

end

