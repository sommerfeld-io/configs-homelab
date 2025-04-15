title "Checks for devcontainer image"

include_controls 'lib' do
end

include_controls 'linux-baseline' do
  skip_control 'os-14'
end

control 'ansible-01' do
  impact 1.0
  title 'Check for essential tools'
  desc 'Ensure essential tools are installed'

  describe file('/usr/bin/curl') do
    it { should exist }
    it { should be_executable }
  end
end
