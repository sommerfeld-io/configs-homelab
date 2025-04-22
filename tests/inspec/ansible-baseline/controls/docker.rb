title 'Docker Image Checks'

control 'docker-images-01' do
  impact 1.0
  title 'Ensure Docker images are present'
  desc 'Mandatory Docker images used for e.g. exposing Prometheus metrics should be present'

  docker_images = [
    { image: 'portainer/portainer-ce', tag: '2.20.3-alpine' },
    { image: 'prom/node-exporter', tag: 'v1.8.1' },
    { image: 'gcr.io/cadvisor/cadvisor', tag: 'v0.49.1' },
  ]

  docker_images.each do |img|
    image = "#{img[:image]}:#{img[:tag]}"

    describe docker_image(image) do
      it { should exist }
      its('repo') { should eq img[:image] }
      its('image') { should eq image }
      its('tag') { should eq img[:tag] }
    end
  end
end
