require 'io/console'

class Log
	$log_prefix = "edelegat-votm"
	$log_postfix = ".log"
	$log_path = "./log/"

	$log_hndl = nil

	$curr_log_no = 0
	$max_ent = 1000
	$ent_cnt = 0

	$log_lock = Mutex.new

	def self.init
		log_file = $log_path+$log_prefix+"0"+$log_postfix

		if not logs_present
			create_logs
			$log_hndl = File.open(log_file, "a")
		else
			$log_hndl = File.open(log_file, "r+")

			if File.size(log_file) > 0
				$ent_cnt = self.count_lines
			else
				$ent_cnt = 0
			end
		end
		$log_hndl.sync = true
	end


	def self.logs_present
		for i in 0..3 do
			ln = $log_path+$log_prefix+i.to_s+$log_postfix
			if not File.file?(ln)
				return false
			end
		end

		return true
	end


	def self.create_logs
		for i in 0..3 do
			ln = $log_path+$log_prefix+i.to_s+$log_postfix
			File.open(ln,"w") {}
		end
	end


	def self.info(msg)
		self.log("[INFO]", msg)
	end


	def self.warning(msg)
		self.log("[WARNING]", msg)
	end


	def self.error(msg)
		self.log("[ERROR]", msg)
	end


	def self.debug(msg)
		c = caller[0]
		self.log("[DEBUG] in: #{c} - ", msg)
	end


	def self.log(log_lvl, msg)
		time = Time.now.strftime("%d.%m %Y %H:%M:%S")
		
		$log_lock.synchronize do
			$log_hndl.puts(time+" "+log_lvl+" "+msg)
		
			$ent_cnt += 1
			if $ent_cnt >= $max_ent
				roll_logs
			end
		end
	end


	def self.roll_logs
		$log_hndl.close

		2.downto(0) do |c|
			cc = c+1
			name_new = $log_path+$log_prefix+cc.to_s+$log_postfix
			name_old = $log_path+$log_prefix+c.to_s+$log_postfix
			
			File.rename(name_old, name_new)
		end

		$log_hndl = File.open($log_path+$log_prefix+"0"+$log_postfix, "a")
		$log_hndl.sync = true
		$ent_cnt = 0
	end


	def self.is_number? string
		true if Integer(string) rescue false
	end
	

	def self.count_lines
		filename = $log_path+$log_prefix+"0"+$log_postfix
		return `wc -l "#{filename}"`.strip.split(' ')[0].to_i
		'''
		line_c = 0	
		$log_hndl.each_line do |line|
			line_c += 1
		end

		$log_hndl.seek(0,IO::SEEK_END)
		return line_c
		'''
	end


	def self.close
		$log_hndl.close
	end
end

# Logger.init
# Logger.log(Logger.ERROR, "test")
# Logger.close
