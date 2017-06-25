require_relative './common'

class POST_FIELD
	COMMAND = "command"
	PARTICIPANTS = "participants"
	ROOM_TYPE = "room_type"
	ROOM_ID = "room_id"
	TIMEOUT = "timeout"
	TOKEN = "token"
	VOTE = "vote"
end


def post_ok(payload)
	status = "HTTP/1.1 200 OK"
	date = Time.now.getutc.strftime("%a, %d %b %Y %H:%M:%S GMT")
	server = "eDelegat Voting Module"
	conten_len = payload.length.to_s
	conten_type = "text/html; charset=UTF-8"
	
	headers = status    + "\r\n" + 
		  "Date: "  + date   + "\r\n" +
		  "Server: "+ server + "\r\n" +
		  "Vary: Accept-Encoding\r\n" +
		  "Conten-Length: " + conten_len  + "\r\n" +
		  "Content-Type: "  + conten_type + "\r\n"

	return (headers+"\r\n"+payload)
end


def post_err(payload)
	status = "HTTP/1.1 500 Server Error"
	date = Time.now.getutc.strftime("%a, %d %b %Y %H:%M:%S GMT")
	server = "eDelegat Voting Module"
	
	conten_len = payload.length.to_s
	conten_type = "text/html; charset=UTF-8"
	
	headers = status    + "\r\n" + 
		  "Date: "  + date   + "\r\n" +
		  "Server: "+ server + "\r\n" +
		  "Vary: Accept-Encoding\r\n" +
		  "Conten-Length: " + conten_len  + "\r\n" +
		  "Content-Type: "  + conten_type + "\r\n"

	return (headers+"\r\n"+payload)
end


def get_post_data(sock)
	headers = sock.gets("\r\n\r\n")
	
	pos_s = headers.index("Content-Length")+16
	pos_e = headers.index("\r\n", pos_s)
	length = headers[pos_s..pos_e]
	parameters = sock.gets(length.to_i)
	
	return parameters.split("&")
end


def parse_client_post(parameters)
	if parameters.size != 4 
		Log.error("Wrong parameter count in REGISTER_VOTE command message")
		return nil, ERR::BAD_PARAM_COUNT
	end
	
	cmd = nil
	parameters.each do |param|
		param = param.split("=")
		case param[0]
		when POST_FIELD::COMMAND
			if param[1] != COMMAND::REGISTER_VOTE
				Log.error("Unknow command #{param[1]} from client")
				return nil, ERR::UNKNOW_COMMAND
			end
			cmd = $CMD_RV_s.new(COMMAND::REGISTER_VOTE)
		when POST_FIELD::TOKEN
			if param[1].length == VROOM::TOKEN_LEN
				cmd.token = param[1]
			else
				Log.error("Wrong token length. Expected: #{VROOM::TOKEN_LEN} bytes. Got: #{param[1].length}")
				return nil, ERR::BAD_TOKEN_LEN
			end
		when POST_FIELD::ROOM_ID
			if param[1].length == VROOM::ROOM_ID_LEN
				cmd.rid = param[1]
			else
				Log.error("Wrong room id length. Expected: #{VROOM::ROOM_ID_LEN} bytes. Got: #{param[1].length}")
				return nil, ERR::BAD_ROOM_ID_LEN
			end
		when POST_FIELD::VOTE
			if param[1] == "0" or param[1] == "1"
				cmd.vote = param[1]
			else
				Log.error("Got wrong vote value. Expected 0 or 1. Got #{param[1]}")
				return nil, ERR::BAD_VOTE_VALUE
			end
		else
			Log.error("Unknow field #{param[0]} in message from client")
			return nil, ERR::UNKNOW_FILED
		end
	end
	return cmd, ERR::OK
end


def parse_delegat_post(parameters)
	cmd = nil
	parameters.each do |param|
		param = param.split("=")
		case param[0]
		when POST_FIELD::COMMAND
			if param[1] == COMMAND::CREATE_ROOM
				if parameters.length != 4
					Log.error("Wrong parameter count in CREATE ROOM command from eDelegat")
					return nil, ERR::BAD_PARAM_COUNT
				end
				cmd = $CMD_CR_s.new(COMMAND::CREATE_ROOM)
			elsif param[1] == COMMAND::GET_RESULTS
				if parameters.length != 2
					Log.error("Wrong parameter count in GET RESULTS command rom eDelegat")
					return nil, ERR::BAD_PARAM_COUNT
				end
				cmd = $CMD_GR_s.new(COMMAND::GET_RESULTS)
			else
				Log.error("Unknow command #{param[1]} from eDelegat")
				return nil, ERR::UNKNOW_COMMAND
			end
		when POST_FIELD::TIMEOUT
			if param[1].length != 3
				Log.error("Wrong timeout format in eDelegat command. Expected format XXX ie. 010 for 10 seconds. Got: #{param[1]}")
				return nil, ERR::BAD_TIMEOUT_FORMAT
			end

			if param[1].to_i >= VROOM::MIN_TIMEOUT and param[1].to_i <= VROOM::MAX_TIMEOUT 
				cmd.timeout = param[1]
			else
				Log.error("Wrong timeout interval. Expected value in (#{VROOM::MIN_TIMEOUT};#{VROOM::MAX_TIMEOUT}). Got: #{param[1]}")
				return nil, ERR::BAD_TIMEOUT_INTERVAL
			end
		when POST_FIELD::ROOM_TYPE
			if param[1] == VROOM::PUB_VOTING or param[1] == VROOM::PRIV_VOTING
				cmd.rm_type = param[1]
			else
				Log.error("Wrong voting room type. Expected #{VROOM::PUB_VOTING} or #{VROOM::PRIV_VOTING}. Got:#{param[1]}")
				return nil, ERR::BAD_ROOM_TYPE
			end
		when POST_FIELD::PARTICIPANTS
			names = param[1].split("-")
			count = names.length
			if count <= 1
				Log.error("Coulnd not find more than one participant. Treating as bad formated command message")
				return nil, ERR::NOT_ENOUGH_PARTICIPANTS
			end
			cmd.names = names
			cmd.pc = count
		when POST_FIELD::ROOM_ID
			if param[1].length == VROOM::ROOM_ID_LEN
				cmd.rid = param[1]
			else
				Log.error("Wrong length of room id #{param[1]}. Expected #{VROOM::ROOM_ID_LEN} chars. Got: #{param[1].length} chars")
				return nil, ERR::BAD_ROOM_ID_LEN
			end
		else
			Log.error("Unknow field #{param[0]} in message from eDelegat")
			return nil, ERR::UNKNOW_FILED
		end
	end
	return cmd, ERR::OK
end
