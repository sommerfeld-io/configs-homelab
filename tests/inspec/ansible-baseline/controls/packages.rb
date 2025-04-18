title "Ensure common packages are installed"

username = input('username', value: 'default_user')
emailAddress = input('emailAddress', value: 'noreply@example.com')
default_mode = input('default_mode', value: '0755')

control 'packages-01' do
  impact 1.0
  title 'Check for essential tools'
  desc 'Ensure essential tools are installed
    Ansible tasks
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
  control 'packages-02a-amd64' do
    impact 1.0
    title 'Check for amd64 specific packages'
    desc 'Ensure amd64 specific packages are installed
      This applies to Ubuntu workstations
      Ansible tasks
      * components/ansible/tasks/ubuntu-ansible.yml
      * components/ansible/tasks/ubuntu-chrome.yml
      * components/ansible/tasks/ubuntu-docker.yml
      * components/ansible/tasks/ubuntu-github-cli.yml
      * components/ansible/tasks/ubuntu-minikube.yml
      * components/ansible/tasks/ubuntu-packages.yml'

    binaries = [
      '/usr/bin/ansible',
      '/usr/bin/asciidoctor',
      '/usr/bin/balena-etcher',
      '/usr/bin/chromium-browser',
      '/usr/bin/conky',
      '/usr/bin/docker',
      '/usr/bin/filezilla',
      '/usr/bin/gh',
      '/usr/bin/minikube',
      '/usr/bin/nmap',
      '/usr/bin/p7zip',
      '/usr/bin/rar',
      '/usr/bin/rpi-imager',
      '/usr/bin/tilix',
      '/usr/bin/unrar',
      '/usr/bin/vagrant',
      '/usr/bin/virtualbox',
      '/usr/bin/yarn',
      '/usr/local/bin/helm',
      '/usr/local/bin/pre-commit',
    ]

    binaries.each do |binary|
      describe file(binary) do
        it { should exist }
        its('mode') { should cmp default_mode }
      end
    end
  end

  control 'packages-02b-amd64' do
    impact 1.0
    title 'Check for amd64 specific snap packages'
    desc 'Ensure amd64 specific snap packages are installed
      This applies to Ubuntu workstations
      Ansible tasks
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

# control 'packages-02' do
#   impact 1.0
#   title 'Check for essential tools'
#   desc 'Ensure essential tools are installed
#     Ansible task
#     * components/ansible/tasks/common-packages.yml'

#   binaries = [
#     '/usr/bin/ansible',
#     '/usr/bin/asciidoctor',
#     '/usr/bin/balena-etcher',
#     '/usr/bin/curl',
#     '/usr/bin/docker',
#     '/usr/bin/filezilla',
#     '/usr/bin/gh',
#     '/usr/bin/git',
#     '/usr/bin/htop',
#     '/usr/bin/jq',
#     '/usr/bin/make',
#     '/usr/bin/ncdu',
#     '/usr/bin/neofetch',
#     '/usr/bin/nmap',
#     '/usr/bin/rpi-imager',
#     '/usr/bin/task',
#     '/usr/bin/tilix',
#     '/usr/bin/vagrant',
#     '/usr/bin/virtualbox',
#     '/usr/bin/vim',
#     '/usr/bin/yarn',
#     '/usr/bin/rar',
#     '/usr/bin/unrar',
#     '/usr/bin/p7zip',
#     '/usr/local/bin/pre-commit',
#     '/snap/bin/postman',
#     '/snap/bin/spotify',
#     # '~/.atuin/bin/atuin',
#     # TODO intellij
#     # TODO vscode
#     # TODO sublime
#   ]

#   binaries.each do |binary|
#     describe file(binary) do
#       it { should exist }
#       it { should be_executable }
#     end
#   end
# end
