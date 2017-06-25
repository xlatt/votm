require 'thread'
require 'securerandom'

require_relative './common'

class VotingRoom
	# Hash map contaning token struct and id of that token
	@tokens


	# Actual count of tokens. Is modified during voting session.
	@token_count


	# ID of voting room. Used for verification of tokens.
	@id


	# Structure of token:vote.
	# Holds data just during of voting. Final results
	# are computed from this data and stored in @results
	@votes


	@participants

	# Tokens struct contains:
	# - value : String containig actual token
	# - used : Bool flag. If false token was not yet used
	# - owner : 
	@Token


	# Room type
	#	PU - Public voting
	#	PR - Private voting
	@type


	# Room time boundaries
	@time_start
	@time_end

	# Hold tokens sent when room is active
	# Array of <vote>:<token>
	@used_tokens


	def initialize(type, token_count, participants, timeout)
		@token_count = token_count
		@tokens = Hash.new(@token_count)
		@used_tokens = Queue.new
		@Token = Struct.new(:value, :used, :owner, :cant_touch_this)
		@participants = participants
		@type = type
		@time_start = get_time(0)
		@time_end = get_time(timeout)

		generate_tokens
		generate_id
	end


	def is_active
		return get_time(0) < @time_end ? true : false
	end


	def get_tokens
		return @tokens
	end


	def get_id
		return @id
	end
	

	def get_time(offset)
		return (Time.now + (offset.to_i)).strftime("%H%M%S")
	end


	def is_old
		return get_time(VROOM::OLD_OFFSET) >= @time_end ? true : false
	end

	def get_results
		yes = no = abstain = 0
		results = Array.new(3)
		vote_stats = Array.new(3)
		votes = Array.new

		if @type == VROOM::PRIV_VOTING
			votes.push("anon")
		end

		@used_tokens.each do |ut|
			vt = ut.split(":")
			k = gen_key(vt[1])
			v = vt[0]
			tkn = @tokens.delete(k)
			
			if v == "0" # no
				no += 1
			elsif v == "1" # yes
				yes += 1
			end
			
			if @type == VROOM::PUB_VOTING
				votes.push(tkn.owner+":"+v)
			end
		end

		# count abstain votes
		if @tokens.size > 0
			@tokens.each do |k,v|
				abstain += 1
				if @type == VROOM::PUB_VOTING
					votes.push(v.owner+":2")
				end
			end
		end

		vote_stats[0] = no
		vote_stats[1] = yes
		vote_stats[2] = abstain

		results[0] = @id
		results[1] = vote_stats
		results[2] = votes

		return results
	end


	def verify_token(token)
		k = gen_key(token)
		begin
			t = @tokens.fetch(k)
			t.cant_touch_this.synchronize do
				if t.used == false
					t.used = true
					return true
				else
					return false
				end
			end
		rescue IndexError
			return false
		end
	end


	def save_vote(vote, token)
		@used_tokens.push(vote+":"+token)
	end


	def generate_tokens
		for i in 0..@token_count-1
			# FIXME get rid ofrjust
			token = SecureRandom.random_number(36**10).to_s(36).rjust(10,"0")
			key = gen_key(token)

			if @type == VROOM::PUB_VOTING
				t = @Token.new(token, false, @participants[i], Mutex.new)
			elsif @type == VROOM::PRIV_VOTING
				t = @Token.new(token, false, "anon", Mutex.new)
			end
			@tokens[key] = t
		end
	end


	def generate_id
		# FIXME get rid of rjust
		@id = SecureRandom.random_number(36**20).to_s(36).rjust(20,"1")
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
end

# r = VotingRoom.new("PU", 1, "a b", 10) 
