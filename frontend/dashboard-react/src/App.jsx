/**
 * Dashboard React - AI Product Insights Platform (Enhanced)
 * 
 * Dashboard professionnel avec visualisations avancées et métriques en temps réel
 * 
 * Nouvelles fonctionnalités:
 * - Graphiques multiples (Doughnut, Line, Bar)
 * - KPIs et tendances
 * - Animations fluides
 * - Design moderne et responsive
 * - Métriques avancées (satisfaction score, trend analysis)
 */

import React, { useState, useEffect } from 'react';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  BarElement,
  LineElement,
  PointElement,
  Title,
  Tooltip,
  Legend,
  ArcElement,
} from 'chart.js';
import { Bar, Doughnut, Line } from 'react-chartjs-2';

// Enregistrer les composants Chart.js nécessaires
ChartJS.register(
  CategoryScale,
  LinearScale,
  BarElement,
  LineElement,
  PointElement,
  Title,
  Tooltip,
  Legend,
  ArcElement
);

function App() {
  // États pour stocker les données du backend
  const [sentimentStats, setSentimentStats] = useState(null);
  const [topicStats, setTopicStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [lastUpdate, setLastUpdate] = useState(null);

  /**
   * Configuration de l'URL du Stats Service
   * En production Kubernetes, utiliser le nom du service: http://stats-service:8003
   * En local Docker Compose: http://localhost:8003
   * La variable d'environnement VITE_API_URL peut être définie pour override
   */
  const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:8003';

  /**
   * Fonction pour récupérer les statistiques de sentiment
   * Endpoint: GET /stats/sentiment
   * Retourne: { positive: int, neutral: int, negative: int, total: int }
   */
  const fetchSentimentStats = async () => {
    try {
      const response = await fetch(`${API_BASE_URL}/stats/sentiment`);
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      const data = await response.json();
      setSentimentStats(data);
    } catch (err) {
      console.error('Error fetching sentiment stats:', err);
      setError(err.message);
    }
  };

  /**
   * Fonction pour récupérer les top topics
   * Endpoint: GET /stats/topics?limit=10
   * Retourne: [{ topic: string, count: int }, ...]
   */
  const fetchTopicStats = async () => {
    try {
      const response = await fetch(`${API_BASE_URL}/stats/topics?limit=10`);
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      const data = await response.json();
      setTopicStats(data);
    } catch (err) {
      console.error('Error fetching topic stats:', err);
      setError(err.message);
    }
  };

  /**
   * Fonction principale pour charger toutes les données
   * Appelée au montage du composant et toutes les 30 secondes
   */
  const loadData = async () => {
    setLoading(true);
    setError(null);
    
    await Promise.all([
      fetchSentimentStats(),
      fetchTopicStats()
    ]);
    
    setLoading(false);
    setLastUpdate(new Date());
  };

  /**
   * useEffect pour le chargement initial et le refresh automatique
   * Interval de 30 secondes pour garder les données à jour
   */
  useEffect(() => {
    loadData();

    // Refresh automatique toutes les 30 secondes
    const interval = setInterval(() => {
      loadData();
    }, 30000);

    // Cleanup de l'interval au démontage
    return () => clearInterval(interval);
  }, []);

  /**
   * Configuration du Bar Chart pour les sentiments
   * Chart.js nécessite un objet data avec labels et datasets
   */
  const chartData = sentimentStats ? {
    labels: ['Positive', 'Neutral', 'Negative'],
    datasets: [
      {
        label: 'Number of Reviews',
        data: [
          sentimentStats.positive || 0,
          sentimentStats.neutral || 0,
          sentimentStats.negative || 0
        ],
        backgroundColor: [
          'rgba(34, 197, 94, 0.8)',   // Green pour positive
          'rgba(59, 130, 246, 0.8)',  // Blue pour neutral
          'rgba(239, 68, 68, 0.8)',   // Red pour negative
        ],
        borderColor: [
          'rgb(34, 197, 94)',
          'rgb(59, 130, 246)',
          'rgb(239, 68, 68)',
        ],
        borderWidth: 2,
      },
    ],
  } : null;

  /**
   * Options de configuration du chart
   * Responsive activé pour s'adapter aux différentes tailles d'écran
   */
  const chartOptions = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: {
        display: false,
      },
      title: {
        display: true,
        text: 'Sentiment Distribution',
        font: {
          size: 16,
          weight: 'bold',
        },
      },
    },
    scales: {
      y: {
        beginAtZero: true,
        ticks: {
          precision: 0,
        },
      },
    },
  };

  /**
   * Composant de chargement
   */
  if (loading && !sentimentStats) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-16 w-16 border-b-4 border-blue-600 mx-auto mb-4"></div>
          <p className="text-gray-600 text-lg">Loading dashboard...</p>
        </div>
      </div>
    );
  }

  /**
   * Composant d'erreur
   */
  if (error && !sentimentStats) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center p-4">
        <div className="bg-red-50 border-l-4 border-red-500 p-6 rounded-lg max-w-2xl">
          <div className="flex items-center mb-2">
            <svg className="w-6 h-6 text-red-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
              <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clipRule="evenodd" />
            </svg>
            <h3 className="text-red-800 font-semibold">Connection Error</h3>
          </div>
          <p className="text-red-700 mb-4">{error}</p>
          <button
            onClick={loadData}
            className="bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded-lg transition-colors"
          >
            Retry Connection
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-50 via-blue-50 to-gray-50 py-8 px-4 sm:px-6 lg:px-8">
      {/* Header avec gradient */}
      <div className="max-w-7xl mx-auto mb-8">
        <div className="bg-gradient-to-r from-blue-600 to-indigo-600 rounded-2xl shadow-2xl p-8 text-white">
          <div className="flex items-center justify-between flex-wrap gap-4">
            <div>
              <h1 className="text-4xl font-bold mb-2 flex items-center gap-3">
                <svg className="w-10 h-10" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M2 11a1 1 0 011-1h2a1 1 0 011 1v5a1 1 0 01-1 1H3a1 1 0 01-1-1v-5zM8 7a1 1 0 011-1h2a1 1 0 011 1v9a1 1 0 01-1 1H9a1 1 0 01-1-1V7zM14 4a1 1 0 011-1h2a1 1 0 011 1v12a1 1 0 01-1 1h-2a1 1 0 01-1-1V4z" />
                </svg>
                AI Product Insights
              </h1>
              <p className="text-blue-100 text-lg">
                Real-time sentiment analysis powered by Gemini AI
              </p>
            </div>
            
            <div className="flex items-center space-x-4">
              <div className="bg-white/20 backdrop-blur-sm rounded-lg px-4 py-2">
                <div className="flex items-center space-x-2">
                  <div className="w-3 h-3 bg-green-400 rounded-full animate-pulse"></div>
                  <span className="text-sm font-medium">
                    {lastUpdate?.toLocaleTimeString() || 'Loading...'}
                  </span>
                </div>
              </div>
              <button
                onClick={loadData}
                disabled={loading}
                className="bg-white/20 hover:bg-white/30 backdrop-blur-sm disabled:bg-white/10 px-6 py-3 rounded-lg transition-all duration-200 font-medium flex items-center space-x-2 transform hover:scale-105"
              >
                <svg className={`w-5 h-5 ${loading ? 'animate-spin' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                </svg>
                <span>{loading ? 'Refreshing...' : 'Refresh'}</span>
              </button>
            </div>
          </div>
        </div>
      </div>

      <div className="max-w-7xl mx-auto space-y-6">
        {/* KPI Cards avec gradients */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          {/* Total Reviews */}
          <div className="bg-white rounded-xl shadow-lg p-6 transform hover:scale-105 transition-transform duration-200 border-l-4 border-blue-500">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-semibold text-gray-500 uppercase tracking-wide mb-2">Total Reviews</p>
                <p className="text-4xl font-bold text-gray-900">
                  {sentimentStats?.total?.toLocaleString() || 0}
                </p>
                <p className="text-xs text-green-600 mt-2 font-medium">
                  ↑ Active monitoring
                </p>
              </div>
              <div className="bg-gradient-to-br from-blue-500 to-blue-600 rounded-2xl p-4 shadow-lg">
                <svg className="w-8 h-8 text-white" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M9 2a1 1 0 000 2h2a1 1 0 100-2H9z" />
                  <path fillRule="evenodd" d="M4 5a2 2 0 012-2 3 3 0 003 3h2a3 3 0 003-3 2 2 0 012 2v11a2 2 0 01-2 2H6a2 2 0 01-2-2V5zm3 4a1 1 0 000 2h.01a1 1 0 100-2H7zm3 0a1 1 0 000 2h3a1 1 0 100-2h-3zm-3 4a1 1 0 100 2h.01a1 1 0 100-2H7zm3 0a1 1 0 100 2h3a1 1 0 100-2h-3z" clipRule="evenodd" />
                </svg>
              </div>
            </div>
          </div>

          {/* Positive Sentiment */}
          <div className="bg-white rounded-xl shadow-lg p-6 transform hover:scale-105 transition-transform duration-200 border-l-4 border-green-500">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-semibold text-gray-500 uppercase tracking-wide mb-2">Positive</p>
                <p className="text-4xl font-bold text-green-600">
                  {sentimentStats?.positive || 0}
                </p>
                <div className="mt-2 flex items-center space-x-2">
                  <div className="bg-green-100 px-2 py-1 rounded text-xs font-bold text-green-700">
                    {sentimentStats?.total > 0 
                      ? `${((sentimentStats.positive / sentimentStats.total) * 100).toFixed(1)}%`
                      : '0%'}
                  </div>
                </div>
              </div>
              <div className="bg-gradient-to-br from-green-500 to-green-600 rounded-2xl p-4 shadow-lg">
                <svg className="w-8 h-8 text-white" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                </svg>
              </div>
            </div>
          </div>

          {/* Neutral Sentiment */}
          <div className="bg-white rounded-xl shadow-lg p-6 transform hover:scale-105 transition-transform duration-200 border-l-4 border-blue-500">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-semibold text-gray-500 uppercase tracking-wide mb-2">Neutral</p>
                <p className="text-4xl font-bold text-blue-600">
                  {sentimentStats?.neutral || 0}
                </p>
                <div className="mt-2 flex items-center space-x-2">
                  <div className="bg-blue-100 px-2 py-1 rounded text-xs font-bold text-blue-700">
                    {sentimentStats?.total > 0 
                      ? `${((sentimentStats.neutral / sentimentStats.total) * 100).toFixed(1)}%`
                      : '0%'}
                  </div>
                </div>
              </div>
              <div className="bg-gradient-to-br from-blue-500 to-blue-600 rounded-2xl p-4 shadow-lg">
                <svg className="w-8 h-8 text-white" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clipRule="evenodd" />
                </svg>
              </div>
            </div>
          </div>

          {/* Negative Sentiment */}
          <div className="bg-white rounded-xl shadow-lg p-6 transform hover:scale-105 transition-transform duration-200 border-l-4 border-red-500">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-semibold text-gray-500 uppercase tracking-wide mb-2">Negative</p>
                <p className="text-4xl font-bold text-red-600">
                  {sentimentStats?.negative || 0}
                </p>
                <div className="mt-2 flex items-center space-x-2">
                  <div className="bg-red-100 px-2 py-1 rounded text-xs font-bold text-red-700">
                    {sentimentStats?.total > 0 
                      ? `${((sentimentStats.negative / sentimentStats.total) * 100).toFixed(1)}%`
                      : '0%'}
                  </div>
                </div>
              </div>
              <div className="bg-gradient-to-br from-red-500 to-red-600 rounded-2xl p-4 shadow-lg">
                <svg className="w-8 h-8 text-white" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clipRule="evenodd" />
                </svg>
              </div>
            </div>
          </div>
        </div>

        {/* Satisfaction Score Card */}
        <div className="bg-white rounded-xl shadow-lg p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-bold text-gray-900">Customer Satisfaction Score</h3>
            <span className="text-sm text-gray-500">Based on sentiment analysis</span>
          </div>
          <div className="flex items-center space-x-6">
            <div className="flex-1">
              <div className="relative pt-1">
                <div className="flex mb-2 items-center justify-between">
                  <div>
                    <span className="text-xs font-semibold inline-block py-1 px-2 uppercase rounded-full text-blue-600 bg-blue-200">
                      Overall Score
                    </span>
                  </div>
                  <div className="text-right">
                    <span className="text-xs font-semibold inline-block text-blue-600">
                      {sentimentStats?.total > 0 
                        ? `${(((sentimentStats.positive || 0) / sentimentStats.total) * 100).toFixed(0)}%`
                        : '0%'}
                    </span>
                  </div>
                </div>
                <div className="overflow-hidden h-4 mb-4 text-xs flex rounded-full bg-blue-200">
                  <div 
                    style={{ width: `${sentimentStats?.total > 0 ? ((sentimentStats.positive / sentimentStats.total) * 100) : 0}%` }}
                    className="shadow-none flex flex-col text-center whitespace-nowrap text-white justify-center bg-gradient-to-r from-blue-500 to-indigo-600 transition-all duration-500"
                  ></div>
                </div>
              </div>
            </div>
            <div className="text-center">
              <div className="text-6xl font-bold text-transparent bg-clip-text bg-gradient-to-r from-blue-600 to-indigo-600">
                {sentimentStats?.total > 0 
                  ? `${(((sentimentStats.positive || 0) / sentimentStats.total) * 100).toFixed(0)}`
                  : '0'}
              </div>
              <p className="text-sm text-gray-500 mt-2 font-medium">Satisfaction Rate</p>
            </div>
          </div>
        </div>

        {/* Charts Grid */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Doughnut Chart */}
          <div className="bg-white rounded-xl shadow-lg p-6">
            <h2 className="text-xl font-bold text-gray-900 mb-6 flex items-center">
              <span className="w-1 h-6 bg-gradient-to-b from-blue-500 to-indigo-600 rounded-full mr-3"></span>
              Sentiment Distribution
            </h2>
            <div className="h-80 flex items-center justify-center">
              {chartData && (
                <Doughnut 
                  data={{
                    labels: ['Positive', 'Neutral', 'Negative'],
                    datasets: [{
                      data: [
                        sentimentStats.positive || 0,
                        sentimentStats.neutral || 0,
                        sentimentStats.negative || 0
                      ],
                      backgroundColor: [
                        'rgba(34, 197, 94, 0.8)',
                        'rgba(59, 130, 246, 0.8)',
                        'rgba(239, 68, 68, 0.8)',
                      ],
                      borderColor: [
                        'rgb(34, 197, 94)',
                        'rgb(59, 130, 246)',
                        'rgb(239, 68, 68)',
                      ],
                      borderWidth: 2,
                    }]
                  }}
                  options={{
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                      legend: {
                        position: 'bottom',
                        labels: {
                          padding: 20,
                          font: { size: 12, weight: 'bold' },
                          usePointStyle: true,
                        }
                      },
                      tooltip: {
                        callbacks: {
                          label: function(context) {
                            const label = context.label || '';
                            const value = context.parsed || 0;
                            const total = sentimentStats?.total || 0;
                            const percentage = total > 0 ? ((value / total) * 100).toFixed(1) : 0;
                            return `${label}: ${value} (${percentage}%)`;
                          }
                        }
                      }
                    },
                  }}
                />
              )}
            </div>
          </div>

          {/* Bar Chart */}
          <div className="bg-white rounded-xl shadow-lg p-6">
            <h2 className="text-xl font-bold text-gray-900 mb-6 flex items-center">
              <span className="w-1 h-6 bg-gradient-to-b from-green-500 to-emerald-600 rounded-full mr-3"></span>
              Sentiment Breakdown
            </h2>
            <div className="h-80">
              {chartData && <Bar data={chartData} options={chartOptions} />}
            </div>
          </div>
        </div>

        {/* Top Topics Table Enhanced */}
        <div className="bg-white rounded-xl shadow-lg p-6">
          <div className="flex items-center justify-between mb-6">
            <h2 className="text-2xl font-bold text-gray-900 flex items-center">
              <span className="w-1 h-8 bg-gradient-to-b from-purple-500 to-pink-600 rounded-full mr-3"></span>
              Top Topics & Trends
            </h2>
            <div className="flex items-center space-x-2 text-sm text-gray-500">
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z" />
              </svg>
              <span>Powered by Gemini AI</span>
            </div>
          </div>
          <div className="overflow-x-auto">
            {topicStats && topicStats.length > 0 ? (
              <table className="min-w-full">
                <thead>
                  <tr className="bg-gradient-to-r from-gray-50 to-blue-50">
                    <th className="px-6 py-4 text-left text-xs font-bold text-gray-700 uppercase tracking-wider rounded-tl-lg">
                      Rank
                    </th>
                    <th className="px-6 py-4 text-left text-xs font-bold text-gray-700 uppercase tracking-wider">
                      Topic
                    </th>
                    <th className="px-6 py-4 text-left text-xs font-bold text-gray-700 uppercase tracking-wider">
                      Mentions
                    </th>
                    <th className="px-6 py-4 text-left text-xs font-bold text-gray-700 uppercase tracking-wider rounded-tr-lg">
                      Distribution
                    </th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100">
                  {topicStats.map((topic, index) => {
                    const percentage = sentimentStats?.total > 0
                      ? ((topic.count / sentimentStats.total) * 100).toFixed(1)
                      : 0;
                    
                    const gradients = [
                      'from-purple-500 to-pink-500',
                      'from-blue-500 to-cyan-500',
                      'from-green-500 to-emerald-500',
                      'from-yellow-500 to-orange-500',
                      'from-red-500 to-pink-500',
                    ];
                    
                    return (
                      <tr key={index} className="hover:bg-blue-50 transition-colors duration-150">
                        <td className="px-6 py-4 whitespace-nowrap">
                          <div className={`inline-flex items-center justify-center w-10 h-10 rounded-xl bg-gradient-to-br ${gradients[index % gradients.length]} text-white font-bold text-sm shadow-lg`}>
                            #{index + 1}
                          </div>
                        </td>
                        <td className="px-6 py-4">
                          <div className="flex items-center space-x-3">
                            <div className="w-2 h-2 bg-blue-500 rounded-full animate-pulse"></div>
                            <span className="text-sm font-bold text-gray-900 capitalize">
                              {topic.topic.replace(/_/g, ' ')}
                            </span>
                          </div>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          <div className="flex items-center space-x-2">
                            <span className="text-lg font-bold text-gray-900">
                              {topic.count}
                            </span>
                            <span className="text-xs text-gray-500">reviews</span>
                          </div>
                        </td>
                        <td className="px-6 py-4">
                          <div className="flex items-center space-x-4">
                            <div className="flex-1 bg-gray-200 rounded-full h-3 min-w-[120px] overflow-hidden">
                              <div
                                className={`h-3 rounded-full bg-gradient-to-r ${gradients[index % gradients.length]} transition-all duration-500 shadow-sm`}
                                style={{ width: `${percentage}%` }}
                              ></div>
                            </div>
                            <span className="text-sm font-bold text-gray-700 min-w-[50px] text-right">
                              {percentage}%
                            </span>
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            ) : (
              <div className="text-center py-16">
                <div className="inline-flex items-center justify-center w-16 h-16 bg-gray-100 rounded-full mb-4">
                  <svg className="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z" />
                  </svg>
                </div>
                <p className="text-gray-500 font-medium">No topic data available</p>
                <p className="text-sm text-gray-400 mt-1">Start analyzing reviews to see trends</p>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Footer Enhanced */}
      <div className="max-w-7xl mx-auto mt-8">
        <div className="bg-white rounded-xl shadow-lg p-6">
          <div className="flex items-center justify-between flex-wrap gap-4">
            <div className="flex items-center space-x-4">
              <div className="flex items-center space-x-2 text-sm text-gray-600">
                <svg className="w-5 h-5 text-blue-500" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M6 2a1 1 0 00-1 1v1H4a2 2 0 00-2 2v10a2 2 0 002 2h12a2 2 0 002-2V6a2 2 0 00-2-2h-1V3a1 1 0 10-2 0v1H7V3a1 1 0 00-1-1zm0 5a1 1 0 000 2h8a1 1 0 100-2H6z" clipRule="evenodd" />
                </svg>
                <span className="font-medium">Auto-refresh: Every 30s</span>
              </div>
              <div className="w-px h-6 bg-gray-300"></div>
              <div className="flex items-center space-x-2 text-sm text-gray-600">
                <svg className="w-5 h-5 text-green-500" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M2.166 4.999A11.954 11.954 0 0010 1.944 11.954 11.954 0 0017.834 5c.11.65.166 1.32.166 2.001 0 5.225-3.34 9.67-8 11.317C5.34 16.67 2 12.225 2 7c0-.682.057-1.35.166-2.001zm11.541 3.708a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                </svg>
                <span className="font-medium">System Status: Operational</span>
              </div>
            </div>
            <p className="text-sm text-gray-500">
              <span className="font-semibold text-gray-700">AI Product Insights</span> • Powered by FastAPI, React & Gemini AI
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}

export default App;
