import { useState, useEffect } from 'react'
import { Link } from 'react-router-dom'
import { supabase } from '../lib/supabase'

const ADMIN_PIN = import.meta.env.VITE_ADMIN_PIN

export default function Admin() {
  const [authenticated, setAuthenticated] = useState(false)
  const [pin, setPin] = useState('')
  const [pinError, setPinError] = useState('')
  const [tab, setTab] = useState('session')

  // Session state
  const [sessions, setSessions] = useState([])
  const [activeSession, setActiveSession] = useState(null)
  const [signups, setSignups] = useState([])

  // New session form
  const [newDate, setNewDate] = useState('')
  const [newTime, setNewTime] = useState('')
  const [newVenue, setNewVenue] = useState('')
  const [newDuration, setNewDuration] = useState('2 hours')
  const [newMax, setNewMax] = useState(25)
  const [creating, setCreating] = useState(false)

  // Image modal
  const [modalImage, setModalImage] = useState(null)

  function handlePinSubmit(e) {
    e.preventDefault()
    if (pin === ADMIN_PIN) {
      setAuthenticated(true)
      setPinError('')
    } else {
      setPinError('Incorrect PIN')
    }
  }

  useEffect(() => {
    if (!authenticated) return
    fetchSessions()
  }, [authenticated])

  useEffect(() => {
    if (!activeSession) return
    fetchSignups()
    const channel = supabase
      .channel('admin-signups')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'signups', filter: `session_id=eq.${activeSession.id}` }, () => {
        fetchSignups()
      })
      .subscribe()
    return () => { supabase.removeChannel(channel) }
  }, [activeSession?.id])

  async function fetchSessions() {
    const { data } = await supabase
      .from('sessions')
      .select('*')
      .order('created_at', { ascending: false })
    setSessions(data || [])
    const open = (data || []).find(s => s.status === 'open')
    if (open) setActiveSession(open)
    else if (data && data.length > 0) setActiveSession(data[0])
  }

  async function fetchSignups() {
    const { data } = await supabase
      .from('signups')
      .select('*')
      .eq('session_id', activeSession.id)
      .order('created_at', { ascending: true })
    setSignups(data || [])
  }

  async function createSession(e) {
    e.preventDefault()
    setCreating(true)

    // Close any open sessions first
    await supabase
      .from('sessions')
      .update({ status: 'closed' })
      .eq('status', 'open')

    // Create new session
    const { data: newSession, error } = await supabase
      .from('sessions')
      .insert({
        date: newDate,
        time_slot: newTime,
        duration: newDuration,
        venue: newVenue,
        max_players: newMax,
        status: 'open',
      })
      .select()
      .single()

    if (!error && newSession) {
      // Auto-add Neo as HOST
      await supabase.from('signups').insert({
        session_id: newSession.id,
        name: 'Neo',
        plus_ones: 0,
        paid: true,
        pay_later: false,
        is_organizer: true,
      })

      setNewDate('')
      setNewTime('')
      setNewVenue('')
      setNewDuration('2 hours')
      setNewMax(20)
      await fetchSessions()
      setActiveSession(newSession)
      setTab('session')
    }
    setCreating(false)
  }

  async function markPaid(id) {
    await supabase.from('signups').update({ paid: true }).eq('id', id)
    fetchSignups()
  }

  async function removeSignup(id) {
    await supabase.from('signups').delete().eq('id', id)
    fetchSignups()
  }

  async function closeSession() {
    if (!activeSession) return
    await supabase.from('sessions').update({ status: 'completed' }).eq('id', activeSession.id)
    fetchSessions()
  }

  function getTotalPlayers() {
    return signups.reduce((sum, s) => sum + 1 + (s.plus_ones || 0), 0)
  }

  function getPrice() {
    return 200
  }

  function getPaidCount() {
    return signups.filter(s => s.paid).reduce((sum, s) => sum + 1 + (s.plus_ones || 0), 0)
  }

  function getRevenue() {
    return signups.filter(s => s.paid).reduce((sum, s) => sum + (1 + (s.plus_ones || 0)) * getPrice(), 0)
  }

  function getStatus(signup) {
    if (signup.is_organizer) return 'host'
    if (signup.paid) return 'paid'
    if (signup.pay_later) return 'reserved'
    if (signup.proof_url) return 'pending'
    return 'pending'
  }

  function formatDate(dateStr) {
    return new Date(dateStr + 'T00:00:00').toLocaleDateString('en-US', {
      weekday: 'short',
      month: 'short',
      day: 'numeric',
    })
  }

  if (!authenticated) {
    return (
      <div className="pin-overlay">
        <div className="pin-box">
          <h2>Admin Access</h2>
          <form onSubmit={handlePinSubmit}>
            <input
              className="input"
              type="password"
              placeholder="Enter PIN"
              value={pin}
              onChange={e => setPin(e.target.value)}
              autoFocus
            />
            <button type="submit" className="btn btn-primary btn-block">
              Enter
            </button>
            {pinError && <div className="pin-error">{pinError}</div>}
          </form>
          <div style={{ marginTop: 20 }}>
            <Link to="/" style={{ fontSize: 13, color: 'var(--text-muted)' }}>← Back to sign up</Link>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="container fade-in">
      <div className="header">
        <h1>Admin <span>Dashboard</span></h1>
        <p><Link to="/">← Back to public page</Link></p>
      </div>

      {/* Tabs */}
      <div className="tab-bar">
        <button className={`tab ${tab === 'session' ? 'active' : ''}`} onClick={() => setTab('session')}>
          Current Session
        </button>
        <button className={`tab ${tab === 'new' ? 'active' : ''}`} onClick={() => setTab('new')}>
          New Session
        </button>
        <button className={`tab ${tab === 'history' ? 'active' : ''}`} onClick={() => setTab('history')}>
          History
        </button>
      </div>

      {/* Current Session Tab */}
      {tab === 'session' && (
        <div className="fade-in">
          {!activeSession || activeSession.status !== 'open' ? (
            <div className="no-session">
              <h2>No active session</h2>
              <p>Create a new session to get started.</p>
              <button className="btn btn-primary" style={{ marginTop: 16 }} onClick={() => setTab('new')}>
                Create Session
              </button>
            </div>
          ) : (
            <>
              {/* Stats */}
              <div className="stats-grid">
                <div className="stat-card">
                  <div className="stat-value">{getTotalPlayers()}</div>
                  <div className="stat-label">Players</div>
                </div>
                <div className="stat-card">
                  <div className="stat-value">{getPaidCount()}</div>
                  <div className="stat-label">Paid</div>
                </div>
                <div className="stat-card">
                  <div className="stat-value">₱{getRevenue()}</div>
                  <div className="stat-label">Revenue</div>
                </div>
              </div>

              {/* Session Details */}
              <div className="card">
                <div className="session-info">
                  <div className="session-info-item">
                    <div className="label">Date</div>
                    <div className="value">{formatDate(activeSession.date)}</div>
                  </div>
                  <div className="session-info-item">
                    <div className="label">Time</div>
                    <div className="value">{activeSession.time_slot}</div>
                  </div>
                  <div className="session-info-item">
                    <div className="label">Venue</div>
                    <div className="value">{activeSession.venue}</div>
                  </div>
                  <div className="session-info-item">
                    <div className="label">Price</div>
                    <div className="value">₱{getPrice()}/head</div>
                  </div>
                </div>
              </div>

              {/* Roster Management */}
              <div className="card">
                <h2 style={{ fontSize: 18, marginBottom: 12 }}>Manage Roster</h2>
                {signups.length === 0 ? (
                  <div className="roster-count">No sign-ups yet.</div>
                ) : (
                  signups.map(s => (
                    <div key={s.id} className="admin-roster-item">
                      <div>
                        <span className="roster-name">{s.name}</span>
                        {s.plus_ones > 0 && <span className="roster-plus">+{s.plus_ones}</span>}
                        <div style={{ marginTop: 4 }}>
                          <span className={`badge badge-${getStatus(s)}`}>{getStatus(s)}</span>
                        </div>
                      </div>
                      <div className="admin-roster-actions">
                        {s.proof_url && (
                          <img
                            src={s.proof_url}
                            alt="proof"
                            className="proof-thumb"
                            onClick={() => setModalImage(s.proof_url)}
                          />
                        )}
                        {!s.paid && !s.is_organizer && (
                          <button className="btn btn-sm btn-primary" onClick={() => markPaid(s.id)}>
                            Mark Paid
                          </button>
                        )}
                        {!s.is_organizer && (
                          <button className="btn btn-sm btn-danger" onClick={() => removeSignup(s.id)}>
                            Remove
                          </button>
                        )}
                      </div>
                    </div>
                  ))
                )}
              </div>

              {/* Close Session */}
              <button className="btn btn-danger btn-block" onClick={closeSession}>
                Close Session
              </button>
            </>
          )}
        </div>
      )}

      {/* New Session Tab */}
      {tab === 'new' && (
        <div className="card fade-in">
          <h2 style={{ fontSize: 18, marginBottom: 16 }}>Create New Session</h2>
          <p style={{ fontSize: 13, color: 'var(--text-muted)', marginBottom: 16 }}>
            Creating a new session will close the current open session.
          </p>
          <form onSubmit={createSession}>
            <div className="form-row">
              <div className="form-group">
                <label>Date</label>
                <input
                  className="input"
                  type="date"
                  value={newDate}
                  onChange={e => setNewDate(e.target.value)}
                  required
                />
              </div>
              <div className="form-group">
                <label>Time</label>
                <input
                  className="input"
                  type="text"
                  placeholder="e.g. 6:00 PM"
                  value={newTime}
                  onChange={e => setNewTime(e.target.value)}
                  required
                />
              </div>
            </div>
            <div className="form-group">
              <label>Venue</label>
              <input
                className="input"
                type="text"
                placeholder="e.g. BGC Activity Center"
                value={newVenue}
                onChange={e => setNewVenue(e.target.value)}
                required
              />
            </div>
            <div className="form-row">
              <div className="form-group">
                <label>Duration</label>
                <select
                  className="input"
                  value={newDuration}
                  onChange={e => setNewDuration(e.target.value)}
                >
                  <option>1 hour</option>
                  <option>1.5 hours</option>
                  <option>2 hours</option>
                  <option>3 hours</option>
                </select>
              </div>
              <div className="form-group">
                <label>Max Players</label>
                <input
                  className="input"
                  type="number"
                  min="5"
                  max="50"
                  value={newMax}
                  onChange={e => setNewMax(Number(e.target.value))}
                />
              </div>
            </div>
            <button
              type="submit"
              className="btn btn-primary btn-block"
              disabled={creating}
            >
              {creating ? 'Creating...' : 'Create Session'}
            </button>
          </form>
        </div>
      )}

      {/* History Tab */}
      {tab === 'history' && (
        <div className="fade-in">
          {sessions.length === 0 ? (
            <div className="no-session">
              <h2>No sessions yet</h2>
            </div>
          ) : (
            sessions.map(s => (
              <div
                key={s.id}
                className="card"
                style={{ cursor: 'pointer', opacity: s.status === 'open' ? 1 : 0.7 }}
                onClick={() => { setActiveSession(s); setTab('session') }}
              >
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div>
                    <div style={{ fontWeight: 600 }}>{formatDate(s.date)}</div>
                    <div style={{ fontSize: 13, color: 'var(--text-muted)' }}>{s.venue} · {s.time_slot}</div>
                  </div>
                  <span className={`badge ${s.status === 'open' ? 'badge-paid' : s.status === 'completed' ? 'badge-host' : 'badge-pending'}`}>
                    {s.status}
                  </span>
                </div>
              </div>
            ))
          )}
        </div>
      )}

      {/* Image Modal */}
      {modalImage && (
        <div className="modal-overlay" onClick={() => setModalImage(null)}>
          <img src={modalImage} alt="Payment proof" />
        </div>
      )}
    </div>
  )
}
