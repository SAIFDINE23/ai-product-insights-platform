/**
 * Dashboard React - AI Product Insights Platform
 * 
 * Ce dashboard connecte le frontend React avec les microservices backend
 * pour visualiser les statistiques de sentiment et les top topics des reviews.
 * 
 * Architecture:
 * - Frontend React (port 5173) ← Vous êtes ici
 * - Stats Service API (port 8003) ← Fournit les données agrégées
 * - AI Analysis Service (port 8002) ← Traite les reviews
 * - PostgreSQL (port 5432) ← Stocke les données
 * 
 * Fonctionnalités:
 * 1. Récupération des stats via fetch API
 * 2. Visualisation des sentiments avec Chart.js (Bar chart)
 * 3. Affichage des top topics dans un tableau
 * 4. Refresh automatique toutes les 30 secondes
 * 5. Design responsive avec TailwindCSS
 */

import React, { useState, useEffect } from 'react';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  BarElement,
  Title,
  Tooltip,
  Legend,
  ArcElement,
} from 'chart.js';
import { Bar } from 'react-chartjs-2';

// Enregistrer les composants Chart.js nécessaires
ChartJS.register(
  CategoryScale,
  LinearScale,
  BarElement,
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
    <div className="min-h-screen bg-gray-50 py-8 px-4 sm:px-6 lg:px-8">
      {/* Header */}
      <div className="max-w-7xl mx-auto mb-8">
        <div className="bg-white rounded-lg shadow-md p-6">
          <h1 className="text-3xl font-bold text-gray-900 mb-2">
            AI Product Insights Dashboard
          </h1>
          <p className="text-gray-600">
            Real-time sentiment analysis and topic extraction from customer reviews
          </p>
          
          {/* Status bar */}
          <div className="mt-4 flex items-center justify-between flex-wrap gap-4">
            <div className="flex items-center space-x-2">
              <div className="w-3 h-3 bg-green-500 rounded-full animate-pulse"></div>
              <span className="text-sm text-gray-600">
                Live - Last update: {lastUpdate?.toLocaleTimeString() || 'N/A'}
              </span>
            </div>
            <button
              onClick={loadData}
              disabled={loading}
              className="bg-blue-600 hover:bg-blue-700 disabled:bg-gray-400 text-white px-4 py-2 rounded-lg transition-colors text-sm font-medium flex items-center space-x-2"
            >
              <svg className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
              </svg>
              <span>{loading ? 'Refreshing...' : 'Refresh'}</span>
            </button>
          </div>
        </div>
      </div>

      <div className="max-w-7xl mx-auto">
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-6">
          {/* Stats Cards */}
          <div className="bg-white rounded-lg shadow-md p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium text-gray-600 mb-1">Total Reviews</p>
                <p className="text-3xl font-bold text-gray-900">
                  {sentimentStats?.total || 0}
                </p>
              </div>
              <div className="bg-blue-100 rounded-full p-3">
                <svg className="w-8 h-8 text-blue-600" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M9 2a1 1 0 000 2h2a1 1 0 100-2H9z" />
                  <path fillRule="evenodd" d="M4 5a2 2 0 012-2 3 3 0 003 3h2a3 3 0 003-3 2 2 0 012 2v11a2 2 0 01-2 2H6a2 2 0 01-2-2V5zm3 4a1 1 0 000 2h.01a1 1 0 100-2H7zm3 0a1 1 0 000 2h3a1 1 0 100-2h-3zm-3 4a1 1 0 100 2h.01a1 1 0 100-2H7zm3 0a1 1 0 100 2h3a1 1 0 100-2h-3z" clipRule="evenodd" />
                </svg>
              </div>
            </div>
          </div>

          <div className="bg-white rounded-lg shadow-md p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium text-gray-600 mb-1">Positive</p>
                <p className="text-3xl font-bold text-green-600">
                  {sentimentStats?.positive || 0}
                </p>
                <p className="text-xs text-gray-500 mt-1">
                  {sentimentStats?.total > 0 
                    ? `${((sentimentStats.positive / sentimentStats.total) * 100).toFixed(1)}%`
                    : '0%'}
                </p>
              </div>
              <div className="bg-green-100 rounded-full p-3">
                <svg className="w-8 h-8 text-green-600" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                </svg>
              </div>
            </div>
          </div>

          <div className="bg-white rounded-lg shadow-md p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium text-gray-600 mb-1">Negative</p>
                <p className="text-3xl font-bold text-red-600">
                  {sentimentStats?.negative || 0}
                </p>
                <p className="text-xs text-gray-500 mt-1">
                  {sentimentStats?.total > 0 
                    ? `${((sentimentStats.negative / sentimentStats.total) * 100).toFixed(1)}%`
                    : '0%'}
                </p>
              </div>
              <div className="bg-red-100 rounded-full p-3">
                <svg className="w-8 h-8 text-red-600" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clipRule="evenodd" />
                </svg>
              </div>
            </div>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Sentiment Chart */}
          <div className="bg-white rounded-lg shadow-md p-6">
            <h2 className="text-xl font-bold text-gray-900 mb-4">Sentiment Analysis</h2>
            <div className="h-80">
              {chartData && <Bar data={chartData} options={chartOptions} />}
            </div>
          </div>

          {/* Top Topics Table */}
          <div className="bg-white rounded-lg shadow-md p-6">
            <h2 className="text-xl font-bold text-gray-900 mb-4">Top Topics</h2>
            <div className="overflow-y-auto max-h-80">
              {topicStats && topicStats.length > 0 ? (
                <table className="min-w-full divide-y divide-gray-200">
                  <thead className="bg-gray-50 sticky top-0">
                    <tr>
                      <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Rank
                      </th>
                      <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Topic
                      </th>
                      <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Count
                      </th>
                      <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Percentage
                      </th>
                    </tr>
                  </thead>
                  <tbody className="bg-white divide-y divide-gray-200">
                    {topicStats.map((topic, index) => {
                      const percentage = sentimentStats?.total > 0
                        ? ((topic.count / sentimentStats.total) * 100).toFixed(1)
                        : 0;
                      
                      return (
                        <tr key={index} className="hover:bg-gray-50 transition-colors">
                          <td className="px-4 py-3 whitespace-nowrap">
                            <span className="inline-flex items-center justify-center w-6 h-6 rounded-full bg-blue-100 text-blue-800 text-sm font-semibold">
                              {index + 1}
                            </span>
                          </td>
                          <td className="px-4 py-3 whitespace-nowrap">
                            <span className="text-sm font-medium text-gray-900 capitalize">
                              {topic.topic}
                            </span>
                          </td>
                          <td className="px-4 py-3 whitespace-nowrap">
                            <span className="text-sm text-gray-600">
                              {topic.count}
                            </span>
                          </td>
                          <td className="px-4 py-3 whitespace-nowrap">
                            <div className="flex items-center">
                              <div className="w-full bg-gray-200 rounded-full h-2 mr-2" style={{ minWidth: '60px' }}>
                                <div
                                  className="bg-blue-600 h-2 rounded-full transition-all duration-300"
                                  style={{ width: `${percentage}%` }}
                                ></div>
                              </div>
                              <span className="text-sm text-gray-600 font-medium">
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
                <div className="text-center py-12">
                  <svg className="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 21h10a2 2 0 002-2V9.414a1 1 0 00-.293-.707l-5.414-5.414A1 1 0 0012.586 3H7a2 2 0 00-2 2v14a2 2 0 002 2z" />
                  </svg>
                  <p className="mt-2 text-sm text-gray-600">No topic data available</p>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>

      {/* Footer */}
      <div className="max-w-7xl mx-auto mt-8">
        <div className="bg-white rounded-lg shadow-md p-4 text-center">
          <p className="text-sm text-gray-600">
            AI Product Insights Platform - Powered by FastAPI, React, and PostgreSQL
          </p>
        </div>
      </div>
    </div>
  );
}

export default App;
