#!/Users/dirk/.rvm/rubies/ruby-1.9.2-p290/bin/ruby

filein = ARGV[0]
fileout = ARGV[1];

if File.readable?(filein) then
	fin = File.open(filein, "r")
else
	puts "Can't read from " + filein
	exit
end

if !File.exists?(fileout) or File.writable?(fileout) then
	fout = File.open(fileout, "w")
else
	puts "Can't write to " + fileout
	exit
end

n = 0
fin.each do |line| 
	n += 1
	if n % 1000 == 0 then
		printf "%6s\t\t\r", n
	end
	if line =~ /^\s*\]\s*\n/ then
		next
	end
	line.gsub!(/^.*?Word\s+([0-9]+)\s*\{\s*([0-9]+)\s*\}.*?\(text=([^)]*)\).*/) {|m| sprintf("%07d %06d %s",$1,$2,$3)}
	line.gsub!(/\\(x..)/) {|m| Integer("0" + $1).chr}
	line = line.force_encoding('utf-8')
	line.sub!(/"([^"]*)"/) {|m| $1.reverse}
	fout.puts(line)
end

fin.close
fout.close

