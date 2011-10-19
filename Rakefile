require 'json'

$name = File.basename(Dir.pwd)
$version = JSON.parse(File.read('manifest.json'))['version']
$crx = "#$name v#$version.crx"

$chrome = "C:\\Users\\Chris Hoffman\\AppData\\Local\\Google\\Chrome\\Application\\chrome.exe"

task :compile do
  system 'coffee', '--output', 'src', '--bare', '--compile', 'lib'
end

task :pack => [:compile] do
  system 'git', 'checkout-index', '-f', '-a', "--prefix=#{File.join($name, '')}"
  system $chrome, "--pack-extension=#{File.join(Dir.pwd, $name)}", "--pack-extension-key=#{File.join(Dir.pwd, "#$name.pem")}", '--no-message-box'
  File.rename("#$name.crx", $crx)
  [$name, *Dir[File.join($name, '*')]].sort.reverse.each do |f|
    File.directory?(f) ? Dir.delete($name) : File.unlink(f)
  end
end

task :release => [:pack] do
  require 'uri'
  dropbox = File.expand_path("~/Dropbox/Public/forums/bioware")

  File.rename($crx, File.join(dropbox, $crx))
  File.open(File.join(dropbox, 'updates.xml'), 'w') do |file|
    file.write <<-EOF
<?xml version='1.0' encoding='UTF-8'?>
<gupdate xmlns='http://www.google.com/update2/response' protocol='2.0'>
<app appid='cmehgfokaheenheaihfbidcphngmkfkk'>
<updatecheck codebase='http://dl.dropbox.com/u/66955/forums/bioware/#{URI.escape($crx)}' version='#$version' />
</app>
</gupdate>
EOF
  end
end
