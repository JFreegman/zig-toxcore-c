const std = @import("std");

const c = @cImport({
    @cInclude("toxcore/tox.h");
});

pub const hex = @import("../src/hex.zig");

const Tox = @This();
const wrap = @import("wrap.zig");
const Friend = @import("friend.zig");
const log = std.log.scoped(.tox);

/// The major version number.
/// Incremented when the API or ABI changes in an incompatible way.
/// The function variants of these constants return the version number of the
/// library. They can be used to display the Tox library version or to check
/// whether the client is compatible with the dynamically linked version of Tox.
pub fn versionMajor() u32 {
    return c.tox_version_major();
}
test "major version should be 0" {
    try std.testing.expectEqual(versionMajor(), 0);
}

/// The minor version number.
/// Incremented when functionality is added without  breaking the API or ABI.
/// Set to 0 when the major version number is incremented.
pub fn versionMinor() u32 {
    return c.tox_version_minor();
}
test "minor version should not be 0" {
    try std.testing.expect(versionMinor() != 0);
}

/// The patch or revision number.
/// Incremented when bugfixes are applied without changing any functionality or
/// API or ABI.
pub fn versionPatch() u32 {
    return c.tox_version_patch();
}
/// Return whether the compiled library version is compatible with the
/// passed version numbers.
pub fn versionIsCompatible(major: u32, minor: u32, patch: u32) bool {
    return c.tox_version_is_compatible(major, minor, patch);
}
/// The size of a Tox Public Key in bytes.
pub fn publicKeySize() u32 {
    return c.tox_public_key_size();
}
/// The size of a Tox Secret Key in bytes.
pub fn secretKeySize() u32 {
    return c.tox_secret_key_size();
}
/// The size of a Tox Conference unique id in bytes.
pub fn conferenceIdSize() u32 {
    return c.tox_conference_id_size();
}
/// The size of the nospam in bytes when written in a Tox address.
pub fn nospamSize() u32 {
    return c.tox_nospam_size();
}
/// The size of a Tox address in bytes.
/// Tox addresses are in the format
/// `[Public Key (TOX_PUBLIC_KEY_SIZE bytes)][nospam (4 bytes)][checksum (2 bytes)]`.
///
/// The checksum is computed over the Public Key and the nospam value. The first
/// byte is an XOR of all the even bytes (0, 2, 4, ...), the second byte is an
/// XOR of all the odd bytes (1, 3, 5, ...) of the Public Key and nospam.
pub fn addressSize() u32 {
    return c.tox_address_size();
}
pub const address_size: u32 = c.TOX_ADDRESS_SIZE;

/// Maximum length of a nickname in bytes.
pub fn maxNameLength() u32 {
    return c.tox_max_name_length();
}
/// Maximum length of a status message in bytes.
pub fn maxStatusMessageLength() u32 {
    return c.tox_max_status_message_length();
}
/// Maximum length of a friend request message in bytes.
pub fn maxFriendRequestLength() u32 {
    return c.tox_max_friend_request_length();
}
///  Maximum length of a single message after which it should be split.
pub fn maxMessageLength() u32 {
    return c.tox_max_message_length();
}
/// Maximum size of custom packets. TODO(iphydf): should be LENGTH?
pub fn maxCustomPacketLength() u32 {
    return c.tox_max_custom_packet_size();
}
/// The number of bytes in a hash generated by tox_hash.
pub fn hashLength() u32 {
    return c.tox_hash_length();
}
/// The number of bytes in a file id.
pub fn fileIdLength() u32 {
    return c.tox_file_id_length();
}
/// Maximum file name length for file transfers.
pub fn maxFilenameLength() u32 {
    return c.tox_max_filename_length();
}
/// Maximum length of a hostname, e.g. proxy or bootstrap node names.
/// This length does not include the NUL byte. Hostnames are NUL-terminated C
/// strings, so they are 255 characters plus one NUL byte.
pub fn maxHostnameLength() u32 {
    return c.tox_max_hostname_length();
}

/// checksum
pub fn dataCheckSum(data: []const u8) u16 {
    var checksum = [_]u8{0} ** 2;
    var check: u16 = 0;

    for (data, 0..) |d, i| {
        checksum[i % 2] ^= d;
    }

    @memcpy(@as([*]u8, @ptrCast(&check)), &checksum);
    return check;
}

// Format: `[real_pk (32 bytes)][nospam number (4 bytes)][checksum (2 bytes)]`
//
// @param[out] address FRIEND_ADDRESS_SIZE byte address to give to others.
pub fn addressFromPublicKey(
    public_key: []const u8,
    nospam_host: u32,
    address: []u8,
) ![]const u8 {
    if (address.len < address_size)
        return error.BufferTooSmall;
    const nospam_net = std.mem.nativeToBig(u32, nospam_host);
    @memcpy(address[0..public_key.len], public_key);
    @memcpy(address[public_key.len..], @as([*]const u8, @ptrCast(&nospam_net)));
    const nospam_len = @sizeOf(@TypeOf(nospam_net));
    const check = dataCheckSum(address[0 .. public_key.len + nospam_len]);
    @memcpy(address[public_key.len + nospam_len ..], @as([*]const u8, @ptrCast(&check)));
    return address[0..];
}

/// Type of proxy used to connect to TCP relays.
pub const ProxyType = enum(c.enum_Tox_Proxy_Type) {
    /// Don't use a proxy.
    none = c.TOX_PROXY_TYPE_NONE,
    /// HTTP proxy using CONNECT.
    http = c.TOX_PROXY_TYPE_HTTP,
    /// SOCKS proxy for simple socket pipes.
    socks5 = c.TOX_PROXY_TYPE_SOCKS5,
};

/// Type of savedata to create the Tox instance from.
pub const SavedataType = enum(c.enum_Tox_Savedata_Type) {
    /// No savedata.
    none = c.TOX_SAVEDATA_TYPE_NONE,
    /// Savedata is one that was obtained from tox_get_savedata.
    save = c.TOX_SAVEDATA_TYPE_TOX_SAVE,
    /// Savedata is a secret key of length TOX_SECRET_KEY_SIZE.
    key = c.TOX_SAVEDATA_TYPE_SECRET_KEY,
};

///  Severity level of log messages.
pub const Options = struct {
    /// The type of socket to create.
    ///
    /// If this is set to false, an IPv4 socket is created, which subsequently
    /// only allows IPv4 communication.
    /// If it is set to true, an IPv6 socket is created, allowing both IPv4 and
    /// IPv6 communication.
    ipv6_enabled: bool = true,

    /// Enable the use of UDP communication when available.
    ///
    /// Setting this to false will force Tox to use TCP only. Communications will
    /// need to be relayed through a TCP relay node, potentially slowing them down.
    /// If a proxy is enabled, UDP will be disabled if either toxcore or the
    /// proxy don't support proxying UDP messages.
    udp_enabled: bool = true,

    /// Enable local network peer discovery.
    ///
    /// Disabling this will cause Tox to not look for peers on the local network.
    local_discovery_enabled: bool = true,

    /// Enable storing DHT announcements and forwarding corresponding requests.
    ///
    /// Disabling this will cause Tox to ignore the relevant packets.
    dht_announcements_enabled: bool = true,

    /// Pass communications through a proxy.
    proxy_type: ProxyType = ProxyType.none,

    /// The IP address or DNS name of the proxy to be used.
    ///
    /// If used, this must be non-NULL and be a valid DNS name. The name must not
    /// exceed TOX_MAX_HOSTNAME_LENGTH characters, and be in a NUL-terminated C string
    /// format (TOX_MAX_HOSTNAME_LENGTH includes the NUL byte).
    ///
    /// This member is ignored (it can be NULL) if proxy_type is TOX_PROXY_TYPE_NONE.
    ///
    /// The data pointed at by this member is owned by the user, so must
    /// outlive the options object.
    proxy_host: ?[:0]const u8 = null,

    /// The port to use to connect to the proxy server.
    ///
    /// Ports must be in the range (1, 65535). The value is ignored if
    /// proxy_type is TOX_PROXY_TYPE_NONE.
    proxy_port: ?u16 = null,

    /// The start port of the inclusive port range to attempt to use.
    ///
    /// If both start_port and end_port are 0, the default port range will be
    /// used: `[33445, 33545]`.
    ///
    /// If either start_port or end_port is 0 while the other is non-zero, the
    /// non-zero port will be the only port in the range.
    ///
    /// Having start_port > end_port will yield the same behavior as if start_port
    /// and end_port were swapped.
    start_port: u16 = 0,

    /// The end port of the inclusive port range to attempt to use.
    end_port: u16 = 0,

    /// The port to use for the TCP server (relay). If 0, the TCP server is
    /// disabled.
    ///
    /// Enabling it is not required for Tox to function properly.
    ///
    /// When enabled, your Tox instance can act as a TCP relay for other Tox
    /// instance. This leads to increased traffic, thus when writing a client
    /// it is recommended to enable TCP server only if the user has an option
    /// to disable it.
    tcp_port: u16 = 0,

    /// Enables or disables UDP hole-punching in toxcore. (Default: enabled).
    hole_punching_enabled: bool = true,

    /// The type of savedata to load from.
    savedata_type: SavedataType = SavedataType.none,

    /// The savedata.
    ///
    /// The data pointed at by this member is owned by the user, so must
    /// outlive the options object.
    savedata_data: ?[:0]const u8 = null,
    // The length of the savedata.
    // size_t savedata_length;
    /// if enabled, log traces as debug messages
    log_traces: bool = true,
    log: bool = true,

    /// Logging callback for the new tox instance.
    //log_cb: ?*log_callback;

    /// User data pointer passed to the logging callback.
    //user_data: ;

    experimental_thread_safety: bool = false,
};

handle: *c.Tox,
friend: Friend,

const Error = error{
    ToxOptionsMallocFailed,
    ToxOptionsProxyHostTooLong,
    ToxOptionsProxyHostMissing,
    ToxOptionsProxyPortMissing,
    ToxOptionsSavedataDataMissing,
    /// One of the arguments to the function was NULL when it was not expected.
    ToxNewNull,
    /// The function was unable to allocate enough memory to store the events_alloc
    /// structures for the Tox object.
    ToxNewMalloc,
    /// The function was unable to bind to a port. This may mean that all ports
    /// have already been bound, e.g. by other Tox instances, or it may mean
    /// a permission error. You may be able to gather more information from errno.
    ToxNewPortAlloc,
    /// proxy_type was invalid.
    ToxNewProxyBadType,
    /// proxy_type was valid but the proxy_host passed had an invalid format
    /// or was NULL.
    ToxNewProxyBadHost,
    /// proxy_type was valid, but the proxy_port was invalid.
    ToxNewProxyBadPort,
    /// The proxy address passed could not be resolved.
    ToxNewProxyNotFound,
    /// The byte array to be loaded contained an encrypted save.
    ToxNewLoadEncrypted,
    /// The data format was invalid. This can happen when loading data that was
    /// saved by an older version of Tox, or when the data has been corrupted.
    /// When loading from badly formatted data, some data may have been loaded,
    /// and the rest is discarded. Passing an invalid length parameter also
    /// causes this error.
    ToxNewLoadBadFormat,
    BufferTooSmall,
};

pub fn init(opt: Options) !Tox {
    var self: Tox = Tox{ .handle = undefined, .friend = undefined };
    var err_opt: c.Tox_Err_Options_New = c.TOX_ERR_OPTIONS_NEW_OK;
    const o: [*c]c.struct_Tox_Options =
        c.tox_options_new(&err_opt);
    if (err_opt != c.TOX_ERR_OPTIONS_NEW_OK)
        return error.ToxOptionsMallocFailed;
    defer c.tox_options_free(o);
    c.tox_options_set_ipv6_enabled(o, opt.ipv6_enabled);
    c.tox_options_set_udp_enabled(o, opt.udp_enabled);
    c.tox_options_set_hole_punching_enabled(o, opt.hole_punching_enabled);
    c.tox_options_set_local_discovery_enabled(o, opt.local_discovery_enabled);
    c.tox_options_set_dht_announcements_enabled(o, opt.dht_announcements_enabled);
    c.tox_options_set_experimental_thread_safety(o, opt.experimental_thread_safety);
    c.tox_options_set_proxy_type(o, @intFromEnum(opt.proxy_type));
    if (opt.proxy_type != ProxyType.none) {
        if (opt.proxy_host) |host| {
            if (host.len > c.TOX_MAX_HOSTNAME_LENGTH)
                return error.ToxOptionsProxyHostTooLong;
            c.tox_options_set_proxy_host(o, host);
        } else return error.ToxOptionsProxyHostMissing;
        if (opt.proxy_port) |port| {
            c.tox_options_set_proxy_port(o, port);
        } else return error.ToxOptionsProxyPortMissing;
    }
    c.tox_options_set_savedata_type(o, @intFromEnum(opt.savedata_type));
    if (opt.savedata_type != SavedataType.none) {
        if (opt.savedata_data) |data| {
            c.tox_options_set_savedata_data(o, data, data.len);
        } else return error.ToxOptionsSavedataDataMissing;
    }
    if (opt.log) {
        c.tox_options_set_log_callback(o, &tox_log);
    }
    var err: c.Tox_Err_New = undefined;
    const maybe_tox = c.tox_new(o, &err);
    switch (err) {
        c.TOX_ERR_NEW_OK => {},
        c.TOX_ERR_NEW_NULL => {
            return error.ToxNewNull;
        },
        c.TOX_ERR_NEW_MALLOC => {
            return error.ToxNewMalloc;
        },
        c.TOX_ERR_NEW_PORT_ALLOC => {
            return error.ToxNewPortAlloc;
        },
        c.TOX_ERR_NEW_PROXY_BAD_TYPE => {
            return error.ToxNewProxyBadType;
        },
        c.TOX_ERR_NEW_PROXY_BAD_HOST => {
            return error.ToxNewProxyBadHost;
        },
        c.TOX_ERR_NEW_PROXY_BAD_PORT => {
            return error.ToxNewProxyBadPort;
        },
        c.TOX_ERR_NEW_PROXY_NOT_FOUND => {
            return error.ToxNewProxyNotFound;
        },
        c.TOX_ERR_NEW_LOAD_ENCRYPTED => {
            return error.ToxNewLoadEncrypted;
        },
        c.TOX_ERR_NEW_LOAD_BAD_FORMAT => {
            return error.ToxNewLoadBadFormat;
        },
        else => {},
    }
    if (maybe_tox) |tox| {
        self.handle = tox;
        self.friend = .{ .handle = tox };
    } else {
        return error.ToxNewFailed;
    }
    //log.info("Created new tox instance", .{});
    return self;
}

fn tox_log(
    tox: ?*c.Tox,
    level: c.Tox_Log_Level,
    file: [*c]const u8,
    line: u32,
    func: [*c]const u8,
    message: [*c]const u8,
    user_data: ?*anyopaque,
) callconv(.C) void {
    const fmt = "[{s}:{d}:{s}]:{s}";
    const arg = .{ file, line, func, message };

    switch (level) {
        c.TOX_LOG_LEVEL_TRACE => {
            log.debug(fmt, arg);
        },
        // Debug messages such as which port we bind to.
        c.TOX_LOG_LEVEL_DEBUG => {
            log.debug(fmt, arg);
        },
        // Informational log messages such as video call status changes.
        c.TOX_LOG_LEVEL_INFO => {
            log.info(fmt, arg);
        },
        // Warnings about events_alloc inconsistency or logic errors.
        c.TOX_LOG_LEVEL_WARNING => {
            log.warn(fmt, arg);
        },
        // Severe unexpected errors caused by external or events_alloc inconsistency.
        c.TOX_LOG_LEVEL_ERROR => {
            log.err(fmt, arg);
        },
        else => {
            log.err(fmt, arg);
        },
    }
    _ = tox;
    _ = user_data;
}

/// Releases all resources associated with the Tox instance and
/// disconnects from the network.
///
/// After calling this function, the Tox pointer becomes invalid. No other
/// functions can be called, and the pointer value can no longer be read.
pub fn deinit(self: Tox) void {
    c.tox_kill(self.handle);
}

/// Calculates the number of bytes required to store the tox instance with
/// tox_get_savedata.
/// This function cannot fail. The result is always greater than 0.
/// @see threading for concurrency implications.
pub fn getSavedataSize(self: Tox) usize {
    return c.tox_get_savedata_size(self.handle);
}
/// Store all information associated with the tox instance to a byte array.
///
/// @param savedata A memory region large enough to store the tox instance
/// data. Call get_savedata_size to find the number of bytes required.
pub fn getSavedata(self: Tox, savedata: []u8) void {
    c.tox_get_savedata(self.handle, @ptrCast(savedata));
}

const BootstrapError = error{
    /// One of the arguments to the function was NULL when it was not expected.
    ToxBootNull,
    /// The hostname could not be resolved to an IP address, the IP address
    /// passed was invalid, or the function failed to send the initial request
    /// packet to the bootstrap node or TCP relay.
    ToxBootBadHost,
    /// The port passed was invalid. The valid port range is (1, 65535).
    ToxBootBadPort,
};

/// Sends a "get nodes" request to the given bootstrap node with IP, port,
/// and public key to setup connections.
///
/// This function will attempt to connect to the node using UDP. You must use
/// this function even if Tox_Options.udp_enabled was set to false.
///
/// @param host The hostname or IP address (IPv4 or IPv6) of the node. Must be
///   at most TOX_MAX_HOSTNAME_LENGTH chars, including the NUL byte.
/// @param port The port on the host on which the bootstrap Tox instance is
///   listening.
/// @param public_key The long term public key of the bootstrap node
///   (TOX_PUBLIC_KEY_SIZE bytes).
/// may return an BootstrapError
pub fn bootstrap(
    self: Tox,
    host: [:0]const u8,
    port: u16,
    public_key: []const u8,
) !void {
    var err: c.Tox_Err_Bootstrap = c.TOX_ERR_BOOTSTRAP_OK;
    if (!c.tox_bootstrap(
        self.handle,
        @ptrCast(host),
        port,
        @ptrCast(public_key),
        &err,
    )) {
        switch (err) {
            c.TOX_ERR_BOOTSTRAP_BAD_HOST => {
                return error.ToxBootBadHost;
            },
            c.TOX_ERR_BOOTSTRAP_BAD_PORT => {
                return error.ToxBootBadPort;
            },
            else => {},
        }
    }
}
/// Adds additional host:port pair as TCP relay.
///
/// This function can be used to initiate TCP connections to different ports on
/// the same bootstrap node, or to add TCP relays without using them as
/// bootstrap nodes.
///
/// @param host The hostname or IP address (IPv4 or IPv6) of the TCP relay.
///   Must be at most TOX_MAX_HOSTNAME_LENGTH chars, including the NUL byte.
/// @param port The port on the host on which the TCP relay is listening.
/// @param public_key The long term public key of the TCP relay
///   (TOX_PUBLIC_KEY_SIZE bytes).
/// may return an BootstrapError
pub fn addTcpRelay(
    self: Tox,
    host: [:0]const u8,
    port: u16,
    public_key: [:0]const u8,
) !void {
    var err: c.Tox_Err_Bootstrap = c.TOX_ERR_BOOTSTRAP_OK;
    if (!c.tox_add_tcp_relay(
        self.handle,
        @ptrCast(host),
        port,
        @ptrCast(public_key),
        &err,
    )) {
        switch (err) {
            c.TOX_ERR_BOOTSTRAP_BAD_HOST => {
                return error.ToxBootBadHost;
            },
            c.TOX_ERR_BOOTSTRAP_BAD_PORT => {
                return error.ToxBootBadPort;
            },
            else => {},
        }
    }
}

pub const ConnectionStatus = enum(c.enum_Tox_Connection) {
    /// There is no connection.
    /// This instance, or the friend the state change is about, is now offline.
    none = c.TOX_CONNECTION_NONE,
    /// A TCP connection has been established.
    /// For the own instance, this means it is connected through a TCP relay,
    /// only. For a friend, this means that the connection to that particular
    /// friend goes through a TCP relay.
    tcp = c.TOX_CONNECTION_TCP,
    /// A UDP connection has been established.
    /// For the own instance, this means it is able to send UDP packets to DHT
    /// nodes, but may still be connected to a TCP relay. For a friend, this
    /// means that the connection to that particular friend was built using
    /// direct UDP packets.
    udp = c.TOX_CONNECTION_UDP,
};

pub fn connectionStatusCallback(
    self: Tox,
    comptime Ctx: type,
    comptime handler: anytype,
) void {
    wrap.setCallback(
        self,
        Ctx,
        c.tox_callback_self_connection_status,
        .{ConnectionStatus},
        .{},
        handler,
    );
}

/// Return the time in milliseconds before `tox_iterate()` should be called again
/// for optimal performance.
pub fn iterationInterval(self: Tox) u32 {
    return c.tox_iteration_interval(self.handle);
}

/// The main loop that needs to be run in intervals of `tox_iteration_interval()`
/// milliseconds.
pub fn iterate(self: Tox, context: anytype) void {
    const is_void = (@TypeOf(context) == void);
    // const Context = @TypeOf(context);
    if (is_void)
        c.tox_iterate(self.handle, null)
    else
        c.tox_iterate(self.handle, @as(?*anyopaque, @ptrCast(context)));
}

///  Writes the Tox friend address of the client to a byte array.
///
/// The address is not in human-readable format. If a client wants to display
/// the address, formatting is required.
///
/// @param address A memory region of at least address_size() bytes.
/// if less memory is given then error.BufferTooSmall
/// will be returned.
/// see address_size() for the address format.
pub fn getAddress(self: Tox, address: []u8) !void {
    if (address.len < addressSize())
        return error.BufferTooSmall;
    c.tox_self_get_address(self.handle, @ptrCast(address));
}

/// @brief Set the 4-byte nospam part of the address.
///
/// This value is expected in host byte order. I.e. 0x12345678 will form the
/// bytes `[12, 34, 56, 78]` in the nospam part of the Tox friend address.
///
/// @param nospam Any 32 bit unsigned integer.
pub fn setNospam(self: Tox, nospam: u32) void {
    c.tox_self_set_nospam(self.handle, nospam);
}

/// Get the 4-byte nospam part of the address.
/// This value is returned in host byte order.
pub fn getNospam(self: Tox) u32 {
    return c.tox_self_get_nospam(self.handle);
}

/// Copy the Tox Public Key (long term) from the Tox object.
///
/// @param public_key A memory region of at least TOX_PUBLIC_KEY_SIZE bytes. If
/// capcity of public_key is smaller then error.BufferTooSmall
/// will be returned.
pub fn getPublicKey(self: Tox, public_key: []u8) ![]const u8 {
    const size = publicKeySize();
    if (public_key.len < size)
        return error.BufferTooSmall;
    c.tox_self_get_public_key(self.handle, @ptrCast(public_key));
    return public_key[0..size];
}

/// @brief Copy the Tox Secret Key from the Tox object.
///
/// @param secret_key A memory region of at least TOX_SECRET_KEY_SIZE bytes. If
/// capcity of secret_key is smaller then error.BufferTooSmall
/// will be returned.
pub fn getSecretKey(self: Tox, secret_key: []u8) ![]const u8 {
    if (secret_key.len < secretKeySize())
        return error.BufferTooSmall;
    c.tox_self_get_secret_key(self.handle, @ptrCast(secret_key));
    return secret_key[0..];
}

const InfoError = error{
    /// Information length exceeded maximum permissible size.
    ToxInfoTooLong,
};

/// Set the nickname for the Tox client.
/// Nickname length cannot exceed TOX_MAX_NAME_LENGTH. If length is 0, the name
/// parameter is ignored (it can be NULL), and the nickname is set back to empty.
///
/// @param name A byte array containing the new nickname.
/// @param length The size of the name byte array.
///
/// returns InfoError if len excceds allowed size.
//bool tox_self_set_name(Tox *tox, const uint8_t *name, size_t length, Tox_Err_Set_Info *error);
pub fn setName(self: Tox, name: []const u8) !void {
    var info: c.Tox_Err_Set_Info = c.TOX_ERR_SET_INFO_OK;
    if (!c.tox_self_set_name(self.handle, @ptrCast(name), name.len, &info))
        return error.ToxInfoTooLong;
}
/// Return the length of the current nickname as passed to tox_self_set_name.
///
/// If no nickname was set before calling this function, the name is empty,
/// and this function returns 0.
///
/// @see threading for concurrency implications.
pub fn getNameSize(self: Tox) usize {
    return c.tox_self_get_name_size(self.handle);
}
/// Write the nickname set by tox_self_set_name to a byte array.
///
/// If no nickname was set before calling this function, the name is empty,
/// and this function has no effect.
///
/// Call tox_self_get_name_size to find out how much memory to allocate for
/// the result.
///
/// @param name A valid memory location large enough to hold the nickname.
///   If this parameter is NULL, the function has no effect.
// void tox_self_get_name(const Tox *tox, uint8_t *name);
pub fn getName(self: Tox, name: []u8) ![]const u8 {
    const size = self.getNameSize();
    if (name.len < size)
        return error.BufferTooSmall;
    c.tox_self_get_name(self.handle, @ptrCast(name));
    return name[0..size];
}
/// Set the client's status message.
///
/// Status message length cannot exceed TOX_MAX_STATUS_MESSAGE_LENGTH. If
/// length is 0, the status parameter is ignored (it can be NULL), and the
/// user status is set back to empty.
pub fn setStatusMessage(self: Tox, status_message: []const u8) !void {
    var info: c.Tox_Err_Set_Info = c.TOX_ERR_SET_INFO_OK;
    if (!c.tox_self_set_status_message(
        self.handle,
        @ptrCast(status_message),
        status_message.len,
        &info,
    ))
        return error.ToxInfoTooLong;
}
/// Return the length of the current status message as passed to tox_self_set_status_message.
///
/// If no status message was set before calling this function, the status
/// is empty, and this function returns 0.
///
/// @see threading for concurrency implications.
pub fn getStatusMessageSize(self: Tox) usize {
    return c.tox_self_get_status_message_size(self.handle);
}
/// Write the status message set by tox_self_set_status_message to a byte array.
///
/// If no status message was set before calling this function, the status is
/// empty, and this function has no effect.
///
/// Call tox_self_get_status_message_size to find out how much memory to allocate for
/// the result.
///
/// @param status_message A valid memory location large enough to hold the
///   status message. If this parameter is NULL, the function has no effect.
pub fn getStatusMessage(self: Tox, status_message: []u8) ![]const u8 {
    const size = self.getStatusMessageSize();
    if (status_message.len < size)
        return error.BufferTooSmall;
    c.tox_self_get_status_message(self.handle, @ptrCast(status_message));
    return status_message[0..size];
}

pub const UserStatus = enum(c.enum_Tox_User_Status) {
    /// User is online and available.
    none = c.TOX_USER_STATUS_NONE,
    /// User is away. Clients can set this e.g. after a user defined
    /// inactivity time.
    away = c.TOX_USER_STATUS_AWAY,
    /// User is busy. Signals to other clients that this client does not
    /// currently wish to communicate.
    busy = c.TOX_USER_STATUS_BUSY,
};
/// Set the client's user status.
/// @param status One of the user statuses listed in the enumeration above.
pub fn setStatus(self: Tox, status: UserStatus) void {
    c.tox_self_set_status(self.handle, @intFromEnum(status));
}
/// Returns the client's user status.
pub fn getStatus(self: Tox) UserStatus {
    return @enumFromInt(c.tox_self_get_status(self.handle));
}
pub const std_options = .{
    .log_level = .debug,
};

test {
    std.testing.refAllDecls(@This());
    //_ = wrap;
}

test "String test" {
    try std.testing.expectEqualStrings("Hi", "Hi");
}
