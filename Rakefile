require 'json'

$name = File.basename(Dir.pwd)
$version = JSON.parse(File.read('manifest.json'))['version']
$crx = "#$name v#$version.crx"

$chrome = "C:\\Users\\Chris Hoffman\\AppData\\Local\\Google\\Chrome\\Application\\chrome.exe"
task :pack do
  system 'git', 'checkout-index', '-f', '-a', "--prefix=#{File.join($name, '')}"
  system $chrome, "--pack-extension=#{File.join(Dir.pwd, $name)}", "--pack-extension-key=#{File.join(Dir.pwd, "#$name.pem")}", '--no-message-box'
  File.rename("#$name.crx", $crx)
  [$name, *Dir[File.join($name, '*')]].sort.reverse.each do |f|
    File.directory?(f) ? Dir.delete($name) : File.unlink(f)
  end
end

task :release => [:pack] do
  File.rename($crx, File.join(File.expand_path("~/Dropbox/Public/forums/bioware"), $crx))
end
