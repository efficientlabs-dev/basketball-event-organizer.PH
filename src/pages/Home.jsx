import { useState, useEffect } from 'react'
import { Link } from 'react-router-dom'
import { supabase, supabaseConfigured } from '../lib/supabase'
import gcashQr from '../assets/gcash-qr.jpg'

export default function Home() {
  const [session, setSession] = useState(null)
  const [signups, setSignups] = useState([])
  const [loading, setLoading] = useState(true)
  const [submitting, setSubmitting] = useState(false)
  const [submitted, setSubmitted] = useState(false)

  // Form state
  const [name, setName] = useState('')
  const [plusOnes, setPlusOnes] = useState(0)
  const [payLater, setPayLater] = useState(false)
  const [proofFile, setProofFile] = useState(null)
  const [proofPreview, setProofPreview] = useState(null)

  // Image modal
  const [modalImage, setModalImage] = useState(null)

  useEffect(() => {
    fetchActiveSession()
  }, [])

  useEffect(() => {
    if (!session) return
    fetchSignups()
    const channel = supabase
      .channel('signups-realtime')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'signups', filter: `session_id=eq.${session.id}` }, () => {
        fetchSignups()
      })
      .subscribe()
    return () => { supabase.removeChannel(channel) }
  }, [session?.id])

  async function fetchActiveSession() {
    const { data } = await supabase
      .from('sessions')
      .select('*')
      .eq('status', 'open')
      .order('created_at', { ascending: false })
      .limit(1)
      .single()
    setSession(data)
    setLoading(false)
  }

  async function fetchSignups() {
    const { data } = await supabase
      .from('signups')
      .select('*')
      .eq('session_id', session.id)
      .order('created_at', { ascending: true })
    setSignups(data || [])
  }

  function getTotalPlayers() {
    return signups.reduce((sum, s) => sum + 1 + (s.plus_ones || 0), 0)
  }

  function getPrice() {
    return 200
  }

  function getStatus(signup) {
    if (signup.is_organizer) return 'host'
    if (signup.paid) return 'paid'
    if (signup.pay_later) return 'reserved'
    if (signup.proof_url) return 'pending'
    return 'pending'
  }

  function handleFileChange(e) {
    const file = e.target.files[0]
    if (!file) return
    setProofFile(file)
    setProofPreview(URL.createObjectURL(file))
    setPayLater(false)
  }

  async function handleSubmit(e) {
    e.preventDefault()
    if (!name.trim() || !session) return
    setSubmitting(true)

    let proofUrl = null
    if (proofFile) {
      const ext = proofFile.name.split('.').pop()
      const fileName = `${session.id}/${Date.now()}-${name.replace(/\s+/g, '_')}.${ext}`
      const { data: uploadData, error: uploadError } = await supabase.storage
        .from('proofs')
        .upload(fileName, proofFile)
      if (!uploadError) {
        const { data: urlData } = supabase.storage.from('proofs').getPublicUrl(fileName)
        proofUrl = urlData.publicUrl
      }
    }

    const { error } = await supabase.from('signups').insert({
      session_id: session.id,
      name: name.trim(),
      plus_ones: plusOnes,
      pay_later: payLater,
      proof_url: proofUrl,
      paid: false,
      is_organizer: false,
    })

    if (!error) {
      setSubmitted(true)
      setName('')
      setPlusOnes(0)
      setPayLater(false)
      setProofFile(null)
      setProofPreview(null)
    }
    setSubmitting(false)
  }

  function formatDate(dateStr) {
    return new Date(dateStr + 'T00:00:00').toLocaleDateString('en-US', {
      weekday: 'long',
      month: 'long',
      day: 'numeric',
    })
  }

  if (!supabaseConfigured) {
    return (
      <div className="container">
        <div className="header">
          <h1>Hoops <span>Session</span></h1>
          <p>Community basketball sessions</p>
        </div>
        <div className="card" style={{ textAlign: 'center', padding: '40px' }}>
          <div style={{ fontSize: 40, marginBottom: 12 }}>🏀</div>
          <h2 style={{ fontSize: 20, marginBottom: 8 }}>Setup Required</h2>
          <p style={{ color: 'var(--text-muted)', fontSize: 14, lineHeight: 1.6 }}>
            Set <code>VITE_SUPABASE_URL</code> and <code>VITE_SUPABASE_ANON_KEY</code> in your environment variables to connect the database.
          </p>
        </div>
      </div>
    )
  }

  if (loading) {
    return (
      <div className="container">
        <div className="header">
          <h1>Hoops <span>Session</span></h1>
        </div>
        <div className="card" style={{ textAlign: 'center', padding: '40px' }}>
          Loading...
        </div>
      </div>
    )
  }

  if (!session) {
    return (
      <div className="container">
        <div className="header">
          <h1>Hoops <span>Session</span></h1>
          <p>Community basketball sessions</p>
        </div>
        <div className="no-session">
          <h2>No active session</h2>
          <p>Check back later for the next session!</p>
        </div>
        <div style={{ textAlign: 'center', marginTop: 20 }}>
          <Link to="/admin" style={{ fontSize: 13, color: 'var(--text-muted)' }}>Admin</Link>
        </div>
      </div>
    )
  }

  return (
    <div className="container fade-in">
      <div className="header">
        <h1>Hoops <span>Session</span></h1>
        <p>Community basketball sessions</p>
      </div>

      {/* Session Info */}
      <div className="card">
        <div className="session-info">
          <div className="session-info-item">
            <div className="label">Date</div>
            <div className="value">{formatDate(session.date)}</div>
          </div>
          <div className="session-info-item">
            <div className="label">Time</div>
            <div className="value">{session.time_slot}</div>
          </div>
          <div className="session-info-item">
            <div className="label">Venue</div>
            <div className="value">{session.venue}</div>
          </div>
          <div className="session-info-item">
            <div className="label">Duration</div>
            <div className="value">{session.duration}</div>
          </div>
        </div>
        <div className="price-tag">
          <div className="amount">₱{getPrice()}</div>
          <div className="per">per head (flat rate)</div>
        </div>
        <div className="roster-count">
          {getTotalPlayers()} / {session.max_players} players signed up
        </div>
      </div>

      {/* Sign Up Form */}
      {!submitted ? (
        <div className="card">
          <h2 style={{ fontSize: 18, marginBottom: 16 }}>Sign Up</h2>
          <form onSubmit={handleSubmit}>
            <div className="form-row">
              <div className="form-group">
                <label>Your Name</label>
                <input
                  className="input"
                  type="text"
                  placeholder="Enter your name"
                  value={name}
                  onChange={e => setName(e.target.value)}
                  required
                />
              </div>
              <div className="form-group">
                <label>Plus Ones</label>
                <select
                  className="input"
                  value={plusOnes}
                  onChange={e => setPlusOnes(Number(e.target.value))}
                >
                  {[0, 1, 2, 3, 4, 5].map(n => (
                    <option key={n} value={n}>{n === 0 ? 'Just me' : `+${n}`}</option>
                  ))}
                </select>
              </div>
            </div>

            {plusOnes > 0 && (
              <div style={{ fontSize: 14, color: 'var(--text-muted)', marginBottom: 12 }}>
                Total: ₱{getPrice() * (1 + plusOnes)} for {1 + plusOnes} people
              </div>
            )}

            <div className="divider" />

            <div style={{ textAlign: 'center', marginBottom: 16 }}>
              <label style={{ display: 'block', marginBottom: 8 }}>Send ₱{getPrice() * (1 + plusOnes)} via GCash</label>
              <img
                src={gcashQr}
                alt="GCash QR Code - Azure Runs"
                style={{ maxWidth: 220, borderRadius: 12, border: '2px solid var(--border)' }}
              />
              <div style={{ fontSize: 13, color: 'var(--text-muted)', marginTop: 6 }}>Scan to pay via GCash, then upload screenshot below</div>
            </div>

            <div style={{ marginBottom: 12 }}>
              <label>Payment Proof (GCash Screenshot)</label>
              <div
                className={`upload-area ${proofFile ? 'has-file' : ''}`}
                onClick={() => document.getElementById('proof-input').click()}
              >
                {proofPreview ? (
                  <img src={proofPreview} alt="Proof" style={{ maxWidth: 120, borderRadius: 6 }} />
                ) : (
                  <div>
                    <div style={{ fontSize: 24, marginBottom: 4 }}>📷</div>
                    <div style={{ color: 'var(--text-muted)', fontSize: 14 }}>Tap to upload GCash screenshot</div>
                  </div>
                )}
                <input
                  id="proof-input"
                  type="file"
                  accept="image/*"
                  style={{ display: 'none' }}
                  onChange={handleFileChange}
                />
              </div>
            </div>

            <label className="checkbox-label">
              <input
                type="checkbox"
                checked={payLater}
                onChange={e => {
                  setPayLater(e.target.checked)
                  if (e.target.checked) {
                    setProofFile(null)
                    setProofPreview(null)
                  }
                }}
              />
              Pay later (reserve my spot)
            </label>

            <button
              type="submit"
              className="btn btn-primary btn-block"
              disabled={!name.trim() || submitting || (!proofFile && !payLater)}
            >
              {submitting ? 'Signing up...' : 'Sign Up'}
            </button>
          </form>
        </div>
      ) : (
        <div className="card" style={{ textAlign: 'center' }}>
          <div style={{ fontSize: 32, marginBottom: 8 }}>✅</div>
          <h2 style={{ fontSize: 18, marginBottom: 4 }}>You're in!</h2>
          <p style={{ color: 'var(--text-muted)', fontSize: 14 }}>See you on the court!</p>
          <button
            className="btn btn-secondary btn-sm"
            style={{ marginTop: 12 }}
            onClick={() => setSubmitted(false)}
          >
            Sign up another player
          </button>
        </div>
      )}

      {/* Live Roster */}
      <div className="card">
        <h2 style={{ fontSize: 18, marginBottom: 12 }}>Roster</h2>
        {signups.length === 0 ? (
          <div className="roster-count">No sign-ups yet. Be the first!</div>
        ) : (
          signups.map(s => (
            <div key={s.id} className="roster-item">
              <div>
                <span className="roster-name">{s.name}</span>
                {s.plus_ones > 0 && <span className="roster-plus">+{s.plus_ones}</span>}
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                {s.proof_url && (
                  <img
                    src={s.proof_url}
                    alt="proof"
                    className="proof-thumb"
                    onClick={() => setModalImage(s.proof_url)}
                  />
                )}
                <span className={`badge badge-${getStatus(s)}`}>
                  {getStatus(s)}
                </span>
              </div>
            </div>
          ))
        )}
      </div>

      <div style={{ textAlign: 'center', marginTop: 8, paddingBottom: 20 }}>
        <Link to="/admin" style={{ fontSize: 13, color: 'var(--text-muted)' }}>Admin</Link>
      </div>

      {/* Image Modal */}
      {modalImage && (
        <div className="modal-overlay" onClick={() => setModalImage(null)}>
          <img src={modalImage} alt="Payment proof" />
        </div>
      )}
    </div>
  )
}
