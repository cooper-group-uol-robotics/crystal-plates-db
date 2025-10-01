// app/javascript/pxrd_chart.js
import { Chart, registerables } from 'chart.js'
import zoomPlugin from 'chartjs-plugin-zoom'

// Register Chart.js components and zoom plugin
Chart.register(...registerables, zoomPlugin)

export function renderPxrdChart(canvasId, data, title, format, isMini = false) {
  const ctx = document.getElementById(canvasId)
  if (!ctx) return null
  
  // Destroy existing chart if it exists and it's the main chart
  if (!isMini && window.currentPxrdChart) {
    window.currentPxrdChart.destroy()
  }
  
  const chartOptions = isMini ? {
    // Mini chart options (for index page thumbnails)
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: { display: false },
      title: { display: false },
      tooltip: { enabled: false }
    },
    scales: {
      x: {
        display: false,
        type: 'linear'
      },
      y: {
        display: false,
        type: 'linear'
      }
    },
    elements: {
      line: { tension: 0 }
    },
    animation: false
  } : {
    // Full chart options (for detail pages)
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: { display: false },
      title: { display: false },
      zoom: {
        pan: { enabled: true, mode: 'xy', modifierKey: 'ctrl' },
        zoom: { drag: { enabled: true }, pinch: { enabled: true }, mode: 'xy' }
      }
    },
    scales: {
      x: {
        type: 'linear',
        title: { display: true, text: '2θ (degrees)' },
        ticks: {
          maxTicksLimit: 10,
          callback: function(value) { return parseFloat(value).toFixed(2) }
        }
      },
      y: {
        title: { display: true, text: 'Intensity (counts)' },
        beginAtZero: true
      }
    }
  }
  
  const chart = new Chart(ctx.getContext('2d'), {
    type: 'scatter',
    data: {
      datasets: [{
        label: `${title} (${format?.toUpperCase() || ''})`,
        data: data,
        borderColor: isMini ? 'rgba(13, 110, 253, 0.8)' : 'rgba(54, 162, 235, 1)',
        backgroundColor: isMini ? 'rgba(13, 110, 253, 0.1)' : 'rgba(54, 162, 235, 0.1)',
        showLine: true,
        pointRadius: 0,
        borderWidth: isMini ? 1 : 2,
        fill: false,
        tension: 0.1
      }]
    },
    options: chartOptions
  })
  
  // Store reference globally for cleanup (only for main charts)
  if (!isMini) {
    window.currentPxrdChart = chart
  }
  
  return chart
}