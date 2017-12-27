(*
 * Copyright (c) 2011 Richard Mortier <mort@cantab.net>
 * Copyright (c) 2012 Balraj Singh <balraj.singh@cl.cam.ac.uk>
 * Copyright (c) 2015 Magnus Skjegstad <magnus@skjegstad.com>
 * Copyright (c) 2017 Takayuki Imada <takayuki.imada@gmail.com>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

open Lwt.Infix

type stats = {
   mutable bytes: int64;
   mutable start_time: int64;
   mutable last_time: int64;
}

let st = {
  bytes=0L; start_time = 0L; last_time = 0L
} 
 
module Main (S: Mirage_types_lwt.STACKV4) (Time : Mirage_types_lwt.TIME) = struct

  let server_ip = Ipaddr.V4.of_string_exn "192.168.122.100"
  let server_port = 7001
  let client_port = 7002

  let msg = "0"

  let mlen = String.length msg

  let print_data st =
    let duration = Int64.sub st.last_time st.start_time in
    Logs.info (fun f -> f  "Latency = %.0Lu [ns]" duration);
    Lwt.return_unit

  let write_and_check ip port udp buf =
    S.UDPV4.write ~dst:ip ~dst_port:port udp buf >|= Rresult.R.get_ok

  let pingpongclient dest_ip dport udp clock =
    (* Setting up a buffer and a timer *)
    let a = Cstruct.sub (Io_page.(to_cstruct (get 1))) 0 mlen in
    Cstruct.blit_from_string msg 0 a 0 mlen;

    let rec loop n udp clock buf =
      match n with
      | 0 -> Lwt.return_unit
      | n -> 
        let t0 = Mclock.elapsed_ns clock in
        st.bytes <- 0L;
        st.start_time <- t0;
        st.last_time <- t0;
        (* Data sending *)
        write_and_check dest_ip dport udp buf >>= fun () ->
        Time.sleep_ns (Duration.of_us 2000) >>= fun () -> (* Give server 2[s] to call listen *)
        (* Receiving reqsponse *)
        loop (n-1) udp clock buf
    in

    (* Having a connection *)
    Logs.info (fun f -> f  "pingpong client: Connecting.");

    (* Latency testing *)
    loop 1000 udp clock a >>= fun () ->

    (* Connection closing *)
    Logs.info (fun f -> f  "pingpong client: Closing.");
    Lwt.return_unit

  let start s _time =
    Time.sleep_ns (Duration.of_sec 1) >>= fun () -> (* Give server 1.0 s to call listen *)
    Mclock.connect () >>= fun clock ->
    let t_init = Mclock.elapsed_ns clock in
    st.bytes <- 0L;
    st.start_time <- t_init;
    st.last_time <- t_init;

    S.listen_udpv4 s ~port:client_port (fun ~src ~dst ~src_port buf ->
      let ts_now = Mclock.elapsed_ns clock in
      st.last_time <- ts_now;
      print_data st
    );
    Lwt.async (fun () -> S.listen s);

    let udp = S.udpv4 s in
    pingpongclient server_ip server_port udp clock

end

