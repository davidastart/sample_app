'use client'

import { useEffect, useState } from 'react'
import axios from 'axios'

export default function Home() {
  const [apiStatus, setApiStatus] = useState<any>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const checkAPI = async () => {
      try {
        const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000'
        const response = await axios.get(`${apiUrl}/health`)
        setApiStatus(response.data)
      } catch (error) {
        console.error('Failed to connect to API:', error)
        setApiStatus({ status: 'error', message: 'Cannot connect to backend' })
      } finally {
        setLoading(false)
      }
    }

    checkAPI()
  }, [])

  return (
    <main className="flex min-h-screen flex-col items-center justify-center p-24">
      <div className="z-10 max-w-5xl w-full items-center justify-center font-mono text-sm">
        <h1 className="text-4xl font-bold mb-8 text-center">
          Therapist Office Application
        </h1>
        
        <div className="mb-8 text-center">
          <p className="text-lg">HIPAA-Compliant Treatment Planning System</p>
        </div>

        <div className="bg-gray-100 p-6 rounded-lg">
          <h2 className="text-xl font-semibold mb-4">System Status</h2>
          {loading ? (
            <p>Checking backend connection...</p>
          ) : (
            <div>
              <p className="mb-2">
                <span className="font-semibold">Backend:</span>{' '}
                <span className={apiStatus?.status === 'healthy' ? 'text-green-600' : 'text-red-600'}>
                  {apiStatus?.status || 'Unknown'}
                </span>
              </p>
              {apiStatus?.database && (
                <p className="mb-2">
                  <span className="font-semibold">Database:</span>{' '}
                  <span className="text-green-600">{apiStatus.database}</span>
                </p>
              )}
              {apiStatus?.version && (
                <p>
                  <span className="font-semibold">Version:</span> {apiStatus.version}
                </p>
              )}
            </div>
          )}
        </div>

        <div className="mt-8 text-center text-sm text-gray-600">
          <p>Coming Soon: Login, Patient Management, Treatment Planning</p>
        </div>
      </div>
    </main>
  )
}
