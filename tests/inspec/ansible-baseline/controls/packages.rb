title 'Ensure common packages are installed'

username = input('username', value: 'default_user')
emailAddress = input('emailAddress', value: 'noreply@example.com')
default_mode = input('default_mode', value: '0755')

control 'packages-01' do
  impact 1.0
  title 'Check for essential tools'
  desc 'Ensure essential tools are installed
    Ansible tasks:
    * components/ansible/tasks/common-packages.yml'

  binaries = [
    '/usr/bin/curl',
    '/usr/bin/htop',
    '/usr/bin/jq',
    '/usr/bin/make',
    '/usr/bin/ncdu',
    '/usr/bin/neofetch',
    '/usr/bin/vim',
  ]
  binaries.each do |binary|
    describe file(binary) do
      it { should exist }
      its('mode') { should cmp default_mode }
    end
  end
end

if os.arch == 'x86_64'
  control 'packages-02-amd64' do
    impact 1.0
    title 'Check for amd64 specific packages'
    desc 'Ensure amd64 specific packages are installed
      This applies to Ubuntu workstations
      Ansible tasks:
      * components/ansible/tasks/ubuntu-ansible.yml
      * components/ansible/tasks/ubuntu-chrome.yml
      * components/ansible/tasks/ubuntu-docker.yml
      * components/ansible/tasks/ubuntu-github-cli.yml
      * components/ansible/tasks/ubuntu-minikube.yml
      * components/ansible/tasks/ubuntu-packages.yml
      * components/ansible/tasks/ubuntu-sublime.yml'

    binaries = [
      '/usr/bin/ansible',
      '/usr/bin/asciidoctor',
      '/usr/bin/balena-etcher',
      '/usr/bin/chromium-browser',
      '/usr/bin/conky',
      '/usr/bin/docker',
      '/usr/bin/filezilla',
      '/usr/bin/gh',
      '/usr/bin/nmap',
      '/usr/bin/p7zip',
      '/usr/bin/rar',
      '/usr/bin/rpi-imager',
      '/usr/bin/subl', # sublime text
      '/usr/bin/tilix',
      '/usr/bin/unrar',
      '/usr/bin/vagrant',
      '/usr/bin/virtualbox',
      '/usr/local/bin/pre-commit',
    ]
    binaries.each do |binary|
      describe file(binary) do
        it { should exist }
        its('mode') { should cmp default_mode }
      end
    end

    binaries = [
      '/usr/bin/minikube',
      '/usr/bin/yarn',
      '/usr/local/bin/helm',
    ]
    binaries.each do |binary|
      describe file(binary) do
        it { should_not exist }
      end
    end
  end

  control 'packages-03-amd64' do
    impact 1.0
    title 'Check for amd64 specific snap packages'
    desc 'Ensure amd64 specific snap packages are installed
      This applies to Ubuntu workstations
      Ansible tasks:
      * components/ansible/tasks/ubuntu-packages.yml'

    binaries = [
      '/snap/bin/code',
      '/snap/bin/intellij-idea-community',
      '/snap/bin/intellij-idea-ultimate',
      '/snap/bin/postman',
      '/snap/bin/spotify',
    ]
    binaries.each do |binary|
      describe file(binary) do
        it { should exist }
        its('mode') { should cmp default_mode }
      end
    end
  end

  control 'packages-04-amd64' do
    impact 1.0
    title 'Check for amd64 specific packages (media players etc.)'
    desc 'Ensure amd64 specific packages (media players etc.) are installed
      This applies to Ubuntu workstations
      Ansible tasks:
      * components/ansible/tasks/ubuntu-media-players.yml'

    binaries = [
      '/usr/bin/asunder',
      '/usr/bin/brasero',
      '/usr/bin/vlc',
    ]
    binaries.each do |binary|
      describe file(binary) do
        it { should exist }
        its('mode') { should cmp default_mode }
      end
    end
  end
end

if os.arch == 'aarch64'
  control 'packages-02-arm64' do
    impact 1.0
    title 'Check for arm64 specific tools'
    desc 'Ensure arm64 specific tools are installed'

    binaries = [
    ]
    binaries.each do |binary|
      describe file(binary) do
        it { should exist }
        its('mode') { should cmp default_mode }
      end
    end
  end
end
