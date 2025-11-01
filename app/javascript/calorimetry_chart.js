// app/javascript/calorimetry_chart.js
import { Chart, registerables } from 'chart.js'

// Register Chart.js components
Chart.register(...registerables)

export function renderCalorimetryChart(canvasId, datapoints, title, isMini = false) {
  const ctx = document.getElementById(canvasId)
  if (!ctx) return null
  
  // Destroy existing chart if it exists and it's the main chart
  if (!isMini && window.currentCalorimetryChart) {
    window.currentCalorimetryChart.destroy()
  }
  
  const chartOptions = isMini ? {
    // Mini chart options (for thumbnails)
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
      line: { tension: 0.1 }
    },
    animation: false
  } : {
    // Full chart options (for main plots)
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: { display: false },
      title: { display: false }
    },
    scales: {
      x: {
        type: 'linear',
        title: { display: true, text: 'Time (seconds)' },
        ticks: {
          maxTicksLimit: 10,
          callback: function(value) { return parseFloat(value).toFixed(1) }
        }
      },
      y: {
        title: { display: true, text: 'Temperature (°C)' },
        ticks: {
          callback: function(value) { return parseFloat(value).toFixed(1) }
        }
      }
    }
  }
  
  // Convert datapoints to Chart.js format
  const chartData = datapoints.map(point => ({
    x: parseFloat(point.timestamp_seconds),
    y: parseFloat(point.temperature)
  }))
  
  const chart = new Chart(ctx.getContext('2d'), {
    type: 'line',
    data: {
      datasets: [{
        label: `${title}`,
        data: chartData,
        borderColor: isMini ? 'rgba(220, 53, 69, 0.8)' : '#dc3545',
        backgroundColor: isMini ? 'rgba(220, 53, 69, 0.1)' : 'rgba(220, 53, 69, 0.1)',
        pointRadius: isMini ? 0 : 1,
        pointHoverRadius: isMini ? 0 : 3,
        borderWidth: isMini ? 1 : 2,
        fill: true,
        tension: 0.1
      }]
    },
    options: chartOptions
  })
  
  // Store reference globally for cleanup (only for main charts)
  if (!isMini) {
    window.currentCalorimetryChart = chart
  }
  
  return chart
}