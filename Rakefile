require 'json'

$name = 'DAL Gift Manager'
$version = JSON.parse(File.read('manifest.json'))['version']
$crx = "#$name v#$version.crx"

$chrome = "C:\\Users\\Chris Hoffman\\AppData\\Local\\Google\\Chrome\\Application\\chrome.exe"

task :compile do
  system 'coffee', '--output', 'src', '--bare', '--compile', 'lib'
  Dir.delete('-p') if File.exists?('-p')
end

task :pack do
  def rm_r(dir)
    [dir,
     *Dir[File.join(dir, '**', '*')],
     *Dir[File.join(dir, '**', '.*')]].sort.reverse.each do |f|
      next if File.basename(f) == '..' || !File.exists?(f)
      File.directory?(f) ? Dir.delete(f) : File.unlink(f)
    end
  end

  begin
    system 'git', 'checkout-index', '-f', '-a', "--prefix=#{File.join('tmp', '')}"

    system 'coffee', '--output', File.join('tmp', 'src'), '--bare', '--compile', File.join('tmp', 'lib')

    # Temporary fix until node for windows gets its crap together
    Dir.delete('-p') if File.exists?('-p')

    rm_r File.join('tmp', 'lib')

    system $chrome, "--pack-extension=#{File.join(Dir.pwd, 'tmp')}", "--pack-extension-key=#{File.join(Dir.pwd, "#$name.pem")}", '--no-message-box'

    File.rename('tmp.crx', $crx)
  ensure
    rm_r 'tmp'
  end
end

task :distribute => [:pack] do
  dropbox = File.expand_path("~/Dropbox/Public/forums/bioware")
  File.rename($crx, File.join(dropbox, $crx))
end

task :release => [:distribute] do
  require 'uri'
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
