{ config, lib, pkgs, ...}:

with lib;

let
  cfg = config.services.stubby;

  stateDir = "/var/lib/stubby";
  fallbacks = concatMapStringsSep "\n  " (x: "- ${x}") cfg.fallbackProtocols;
  listeners = concatMapStringsSep "\n  " (x: "- ${x}") cfg.listenAddresses;
  # By default, the recursive resolvers maintained by the getdns
  # project itself are enabled. More information about both getdns's servers, # as well as third party options for upstream resolvers, can be found here:
  # https://dnsprivacy.org/wiki/display/DP/DNS+Privacy+Test+Servers
  #
  # You can override these values by supplying a yaml-formatted array of your
  # preferred upstream resolvers in the following format:
  #
  # 106 # - address_data: IPv4 or IPv6 address of the upstream
  #   port: Port for UDP/TCP (default is 53)
  #   tls_auth_name: Authentication domain name checked against the server
  #                  certificate
  #   tls_pubkey_pinset: An SPKI pinset verified against the keys in the server
  #                      certificate
  #     - digest: Only "sha256" is currently supported
  #       value: Base64 encoded value of the sha256 fingerprint of the public
  #              key
  #   tls_port: Port for TLS (default is 853)

  defaultUpstream = ''
    - address_data: 145.100.185.15
      tls_auth_name: "dnsovertls.sinodun.com"
      tls_pubkey_pinset:
        - digest: "sha256"
          value: 62lKu9HsDVbyiPenApnc4sfmSYTHOVfFgL3pyB+cBL4=
    - address_data: 145.100.185.16
      tls_auth_name: "dnsovertls1.sinodun.com"
      tls_pubkey_pinset:
        - digest: "sha256"
          value: cE2ecALeE5B+urJhDrJlVFmf38cJLAvqekONvjvpqUA=
    - address_data: 185.49.141.37
      tls_auth_name: "getdnsapi.net"
      tls_pubkey_pinset:
        - digest: "sha256"
          value: foxZRnIh9gZpWnl+zEiKa0EJ2rdCGroMWm02gaxSc9Q=
    - address_data: 2001:610:1:40ba:145:100:185:15
      tls_auth_name: "dnsovertls.sinodun.com"
      tls_pubkey_pinset:
        - digest: "sha256"
          value: 62lKu9HsDVbyiPenApnc4sfmSYTHOVfFgL3pyB+cBL4=
    - address_data: 2001:610:1:40ba:145:100:185:16
      tls_auth_name: "dnsovertls1.sinodun.com"
      tls_pubkey_pinset:
        - digest: "sha256"
          value: cE2ecALeE5B+urJhDrJlVFmf38cJLAvqekONvjvpqUA=
    - address_data: 2a04:b900:0:100::38
      tls_auth_name: "getdnsapi.net"
      tls_pubkey_pinset:
        - digest: "sha256"
          value: foxZRnIh9gZpWnl+zEiKa0EJ2rdCGroMWm02gaxSc9Q=
  '';

  # Resolution type is not changeable here because it is required per the
  # stubby documentation:
  #
  # "resolution_type: Work in stub mode only (not recursive mode) - required for Stubby
  # operation."
  #
  # https://dnsprivacy.org/wiki/display/DP/Configuring+Stubby

  confFile = pkgs.writeText "stubby.yml" ''
    resolution_type: GETDNS_RESOLUTION_STUB
    dns_transport_list:
      ${fallbacks}
    tls_authentication: ${cfg.authenticationMode}
    tls_query_padding_blocksize: ${toString cfg.queryPaddingBlocksize}
    edns_client_subnet_private: ${if cfg.subnetPrivate then "1" else "0"}
    idle_timeout: ${toString cfg.idleTimeout}
    listen_addresses:
      ${listeners}
    round_robin_upstreams: ${if cfg.roundRobinUpstreams then "1" else "0"}
    ${cfg.extraConfig}
    upstream_recursive_servers:
    ${cfg.upstreamServers}
  '';
in

{
  options = {
    services.stubby = {

      enable = mkEnableOption "Stubby DNS resolver";

      fallbackProtocols = mkOption {
        default = [ "GETDNS_TRANSPORT_TLS" ];
        type = types.listOf types.str;
        description = ''
          Ordered list composed of one or more transport protocols.
          Strict mode should only use GETDNS_TRANSPORT_TLS.
          Other options are GETDNS_TRANSPORT_UDP and GETDNS_TRANSPORT_TCP.
        '';
      };

      authenticationMode = mkOption {
        default = "GETDNS_AUTHENTICATION_REQUIRED";
        type = types.str;
        description = ''
          Selects the Strict or Opportunistic usage profile.
          For strict, set to GETDNS_AUTHENTICATION_REQUIRED.
          for opportunistic, use GETDNS_AUTHENTICATION_NONE.
        '';
      };

      queryPaddingBlocksize = mkOption {
        default = 128;
        type = types.int;
        description = ''
          EDNS0 option to pad the size of the DNS query to the given blocksize.
        '';
      };

      subnetPrivate = mkOption {
        default = true;
        type = types.bool;
        description = ''
          EDNS0 option for ECS client privacy. Default is true.
        '';
      };

      idleTimeout = mkOption {
        default = 10000;
        type = types.int;
        description = "EDNS0 option for keepalive idle timeout.";
      };

      listenAddresses = mkOption {
        default = [ "127.0.0.1" "0::1" ];
        type = types.listOf types.str;
        description = ''
          Sets the listen address for the stubby daemon.
          Uses port 53 by default.
          Ise IP@port to specify a different port.
        '';
      };

      roundRobinUpstreams = mkOption {
        default = true;
        type = types.bool;
        description = ''
          Instructs stubby to distribute queries across all available name servers.
          Default is true. Set to false in order to use the first available.
        '';
      };

      upstreamServers = mkOption {
        default = defaultUpstream;
        type = types.lines;
        description = ''
          Add additional upstreams see <citerefentry><refentrytitle>stubby
          </refentrytitle><manvolnum>1</manvolnum></citerefentry> for an
          example of the entry formatting.
        '';
      };

      enableNetBindService = mkOption {
        default = true;
        type = types.bool;
        description = ''
          This option enables or disables the "CAP_NET_BIND_SERVICE"
          capability for the daemon process. This capability is necessary in the
          default configuration (localhost listening on port 853), but is not 
          necessary if the user chooses to bind to ports higher than 1024 
          and can safely be disabled in this case for increased security. 
          See <citerefentry><refentrytitle> capabilities</refentrytitle>
          <manvolnum>7</manvolnum> </citerefentry> for more information.
        '';
      };

      extraConfig = mkOption {
        default = "";
        type = types.lines;
        description = ''
          Add additional configuration options. see <citerefentry>
          <refentrytitle>stubby</refentrytitle><manvolnum>1</manvolnum>
          </citerefentry>for more options.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.stubby ];
    systemd.services.stubby = {
      description = "Stubby local DNS resolver";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        AmbientCapabilities = "${optionalString cfg.enableNetBindService "CAP_NET_BIND_SERVICE"}";
        CapabilitiesBoundingSet = "${optionalString cfg.enableNetBindService "CAP_NET_BIND_SERVICE"}";
        ExecStart = "${pkgs.stubby}/bin/stubby -C ${confFile}";
        DynamicUser = true;
      };
    };
  };
}
