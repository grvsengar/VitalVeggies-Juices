import { Controller } from "@hotwired/stimulus"
import ApexCharts from "apexcharts"

export default class extends Controller {
  static values = {
    series: Array,
    labels: Array,
    type: String,
    prefix: String,
    colors: Array
  }

  connect() {
    const sparkline = this.element.dataset.sparkline === "true"
    const baseColors = this.colorsValue.length > 0 ? this.colorsValue : ["#1f7a4d", "#f59e0b", "#b42318"]

    const options = {
      series: this.seriesValue,
      chart: {
        type: this.typeValue || "line",
        height: this.element.offsetHeight || 350,
        toolbar: { show: false },
        zoom: { enabled: false },
        fontFamily: "inherit",
        animations: {
          enabled: true,
          easing: "easeinout",
          speed: 650
        },
        sparkline: { enabled: sparkline }
      },
      colors: baseColors,
      dataLabels: { enabled: false },
      stroke: {
        curve: "smooth",
        width: sparkline ? 2 : 3
      },
      labels: this.typeValue === "pie" || this.typeValue === "donut" ? this.labelsValue : undefined,
      xaxis: {
        categories: this.typeValue === "pie" || this.typeValue === "donut" ? undefined : this.labelsValue,
        labels: {
          show: !sparkline
        },
        axisBorder: { show: false },
        axisTicks: { show: false }
      },
      yaxis: {
        labels: {
          show: !sparkline,
          formatter: (value) => {
            return (this.prefixValue || "") + value.toLocaleString()
          }
        }
      },
      grid: {
        show: !sparkline,
        borderColor: "#f1f1f1"
      },
      markers: {
        size: sparkline ? 0 : 4,
        strokeWidth: 0,
        hover: { sizeOffset: 2 }
      },
      tooltip: {
        theme: "light",
        y: {
          formatter: (value) => {
            return (this.prefixValue || "") + value.toLocaleString()
          }
        }
      }
    }

    if (this.typeValue === "bar") {
      options.plotOptions = {
        bar: {
          borderRadius: 4,
          horizontal: true,
          distributed: true,
          barHeight: "68%"
        }
      }
    }

    if (this.typeValue === "area") {
      options.fill = {
        type: "gradient",
        gradient: {
          shadeIntensity: 1,
          opacityFrom: 0.3,
          opacityTo: 0.04,
          stops: [0, 90, 100]
        }
      }
    }

    this.chart = new ApexCharts(this.element, options)
    this.chart.render()
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
    }
  }
}
