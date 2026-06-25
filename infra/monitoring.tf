resource "docker_image" "prometheus" {
  name         = "prom/prometheus:latest"
  keep_locally = true
}

resource "docker_container" "prometheus" {
  name    = "prometheus"
  image   = docker_image.prometheus.image_id
  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.cicd.name
  }

  ports {
    internal = 9090
    external = 9090
  }

  command = [
    "--config.file=/etc/prometheus/prometheus.yml",
    "--storage.tsdb.retention.time=15d"
  ]

  upload {
    content = <<-PROMCFG
      global:
        scrape_interval: 15s
        evaluation_interval: 15s
      scrape_configs:
        - job_name: 'sentiment-ai'
          static_configs:
            - targets: ['sentiment-staging:8000']
          metrics_path: /metrics
        - job_name: 'prometheus'
          static_configs:
            - targets: ['localhost:9090']
    PROMCFG
    file    = "/etc/prometheus/prometheus.yml"
  }
}

resource "docker_image" "grafana" {
  name         = "grafana/grafana:latest"
  keep_locally = true
}

resource "docker_container" "grafana" {
  name    = "grafana"
  image   = docker_image.grafana.image_id
  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.cicd.name
  }

  ports {
    internal = 3000
    external = 3000
  }

  env = ["GF_SECURITY_ADMIN_PASSWORD=admin"]
}
