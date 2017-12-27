open Lwt.Infix

module Main (S: Mirage_types_lwt.STACKV4) = struct

  let return_ip = Ipaddr.V4.of_string_exn "192.168.122.101"
  let server_port = 7001
  let client_port = 7002

  let msg = "0"
  let mlen = String.length msg
  let a = Cstruct.sub (Io_page.(to_cstruct (get 1))) 0 mlen

  let write_and_check ip port udp buf =
    (* Logs.info (fun f -> f "responded!"); *)
    S.UDPV4.write ~dst:ip ~dst_port:port udp buf >|= Rresult.R.get_ok

  let start s =
    let ips = List.map Ipaddr.V4.to_string (S.IPV4.get_ip (S.ipv4 s)) in
    Logs.info (fun f -> f "pingpong server process started:");
    Logs.info (fun f -> f "IP address: %s" (String.concat "," ips));
    Logs.info (fun f -> f "Port number: %d" server_port);

    let udp = S.udpv4 s in

    S.listen_udpv4 s ~port:server_port (fun ~src ~dst ~src_port buf ->
      write_and_check src client_port udp a >>= fun () ->
      Lwt.return_unit
    );
    S.listen s

end

