require 'socket'
require 'thread'
require 'openssl'

require_relative './votr'
require_relative './logger'
require_relative './common'
require_relative './http'

class NET
	LISTEN_ADDR = "192.168.88.2"
	EDELEGAT_PORT = 6969
	CLIENT_PORT = 1337
end

$ACCPT_THRDS_CNT = 40
$client_queue = Queue.new

$v_rooms = Hash.new

$sec_name = nil
$sec_cert = nil
$sec_key = nil
$sec_context = nil

Thread.abort_on_exception = true


Signal.trap("INT") do
	stop
end


Signal.trap("TERM") do
	stop
end


def init
	Log.init
	init_ssl
end


def init_ssl
	$sec_key = OpenSSL::PKey::RSA.new(2048)
	$sec_name = OpenSSL::X509::Name.parse("CN=nobody/DC=localhost")
	
	$sec_cert = OpenSSL::X509::Certificate.new
	$sec_cert.version = 2
	$sec_cert.serial = 0
	$sec_cert.not_before = Time.now
	$sec_cert.not_after = Time.now + 3600
	$sec_cert.public_key = $sec_key.public_key
	$sec_cert.subject = $sec_name
	# Self sign cert
	$sec_cert.issuer = $sec_name
	$sec_cert.sign($sec_key, OpenSSL::Digest::SHA1.new)

	$sec_context = OpenSSL::SSL::SSLContext.new
	$sec_context.cert = $sec_cert
	$sec_context.key = $sec_key
end


def gen_key(str)
	k = str[4]
	z = str[0..2] + str[-3..-1]
	zz = ""
	for i in 0..z.length-1 do
		zz += (z[i].bytes[0] ^ k.bytes[0]).to_s
	end

	return zz
end


def room_ok_resp(room)
	resp = "OKCR"+room.get_id

	room.get_tokens.each do |k,v|
		resp += v.owner+"="+v.value+":"
	end

	return post_ok(resp.chop)
end


def get_room(rid)
	k = gen_key(rid)
	room = nil
	
	begin
		room = $v_rooms.fetch(k), ERR::OK
	rescue IndexError
		Log.warning("Request for results with invalid room id: #{rid}")
	end
	
	return room, ERR::BAD_ROOM_ID
end


def create_room(msg)
	begin
		tries ||= 1
		if $v_rooms.length > VROOM::MAX_ROOM_COUNT
			throw
		end
	rescue
		tries -= 1
		if tries >= 0
			delete_old_rooms
			retry
		else
			Log.warning("Could not create room because maximum count of rooms (#{VROOM::MAX_ROOM_COUNT}) was reached")
			return nil, ERR::MAX_ROOM_COUNT_REACHED
		end
	end

	room = VotingRoom.new(msg.rm_type, msg.pc, msg.names, msg.timeout)

	Log.info("New room created with id: #{room.get_id}")
	return room, ERR::OK
end


def open_room(room)	
	id = room.get_id
	k = gen_key(id)
	$v_rooms[k] = room
end


def get_results(rid)
	room, err = get_room(rid)
	if err != ERR::OK
		return nil, err
	end

	if room.is_active == false
		results = Marshal.dump(room.get_results)

		k = gen_key(rid)
		$v_rooms.delete(k)
		return results, ERR::OK
	else
		log_msg =  "Room: #{rid} is still active. Cannot fetch results"
		Log.warning(log_msg) 
		return nil, ERR::ROOM_STILL_ACTIVE
	end
end


def handle_edelegat(sock)
	data = get_post_data(sock)
	msg, err = parse_delegat_post(data)

	if err != ERR::OK
		sock.puts(post_err(err))
		return
	end

	if msg.cmd == COMMAND::CREATE_ROOM
		room, err = create_room(msg)
		if err == ERR::OK
			open_room(room)
			sock.puts(room_ok_resp(room))
		else
			sock.puts(post_err(err))
		end
	elsif msg.cmd == COMMAND::GET_RESULTS
		results, err = get_results(msg.rid)
		if err == ERR::OK
			sock.puts(post_ok(results))	
		else
			sock.puts(post_err(err))
		end
	end
end


def handle_client(client)
	data = get_post_data(client)

	msg, err = parse_client_post(data)
	if err != ERR::OK
		sock.puts(post_err(err))
		return
	end

	room, err = get_room(msg.rid)
	if err != ERR::OK 
		sock.puts(post_err(err))
		return
	end

	if room.is_active == true
		if room.verify_token(msg.token) == true
			room.save_vote(msg.vote, msg.token)
			client.puts(post_ok(ERR::OK))
		else
			Log.warning("Token #{msg.token} is invalid")
			client.puts(post_err(ERR::BAD_TOKEN))
		end
	else
		Log.warning("Client sent vote for room #{msg.rid} which is no longer active")
		client.puts(post_err(ERR::ROOM_INACTIVE))
	end
end


def delete_old_rooms
	$v_rooms.each do |k,v|
		if v.is_old
			$v_rooms.delete(k)	
		end
	end
end


def handle_edelegats
	sock = TCPServer.open(NET::LISTEN_ADDR, NET::EDELEGAT_PORT)

	Thread.start do
		loop do
			Thread.start(sock.accept) do |ed_sock|
				handle_edelegat(ed_sock)
				ed_sock.close
			end
		end
	end
end


def accept_clients
	clients = TCPServer.new(NET::LISTEN_ADDR, NET::CLIENT_PORT)
	# ssl_clients = OpenSSL::SSL::SSLServer.new(clients, $sec_context)	
	loop do
		$client_queue.push(clients.accept)
	end
end


def handle_clients
	$ACCPT_THRDS_CNT.times do
		Thread.start do
			loop do
				cs = $client_queue.pop()
				handle_client(cs)
				cs.close
			end
		end
	end
end


def start
	handle_edelegats	# accept and handle commands from application 
	handle_clients		# create thread pool for processing accept queue
	accept_clients		# accept clients and fill accept queue
end


def stop
	Log.close
	exit
end


# +------------------------------+
# +				MAIN			 +
# +------------------------------+
init
start
