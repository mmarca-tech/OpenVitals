// DeviceSyncScreen — "Sync with another phone" over Bluetooth. A single
// state-driven wizard (one route, phased state — matching the app's BLE-pair /
// onboarding pattern, not a multi-route flow). Steps: role choice → discoverable
// (host) or discover+code (guest) → time range → data types → transfer → report.
// Composes TopBar, Button, Card, SectionHeader, Checkbox, TimeRangeSelector,
// AccentIconChip, DetailRow, Icon from the design system.
const {
  TopBar, Button, Card, SectionHeader, Checkbox,
  TimeRangeSelector, AccentIconChip, DetailRow, Icon,
} = window.OpenVitalsDesignSystem_626946;

const OV = 'var(--ov-on-surface)';
const OVV = 'var(--ov-on-surface-variant)';
const SANS = 'var(--ov-font-sans)';
const ACCENT = 'var(--ov-primary)';

// The negotiated intersection of both devices' supported types, grouped by the
// importer's category taxonomy (apple_health_import_categories.dart).
const CATEGORIES = [
  ['activity', 'Activity', 'directions_run', 'var(--ov-metric-steps)', 'Steps, distance, calories, floors'],
  ['workouts', 'Workouts', 'fitness_center', 'var(--ov-metric-workout)', 'Exercise sessions, routes, laps'],
  ['heart', 'Heart', 'favorite', 'var(--ov-metric-heart)', 'Heart rate, resting HR, HRV'],
  ['sleep', 'Sleep', 'bedtime', 'var(--ov-metric-sleep)', 'Sleep sessions and stages'],
  ['body', 'Body', 'monitor_weight', 'var(--ov-metric-body)', 'Weight, height, body fat, lean mass'],
  ['vitals', 'Vitals', 'ecg_heart', 'var(--ov-metric-vitals)', 'Blood pressure, SpO2, temperature'],
  ['nutrition', 'Nutrition', 'restaurant', 'var(--ov-metric-nutrition)', 'Meals and nutrients'],
  ['hydration', 'Hydration', 'local_drink', 'var(--ov-metric-hydration)', 'Water and drink intake'],
  ['mindfulness', 'Mindfulness', 'self_improvement', 'var(--ov-metric-mindfulness)', 'Mindfulness sessions'],
  ['cycle', 'Cycle', 'cycle', 'var(--ov-metric-cycle)', 'Menstruation and cycle tracking'],
];

const RANGE_LABELS = ['30 days', '6 months', '1 year', 'All'];

// ── Small shared pieces ──────────────────────────────────────────────────────

function StepDots({ index, count }) {
  return (
    <div style={{ display: 'flex', gap: 6, justifyContent: 'center', padding: '2px 0 10px' }}>
      {Array.from({ length: count }).map((_, i) => (
        <span key={i} style={{
          width: i === index ? 20 : 6, height: 6, borderRadius: 999,
          background: i <= index ? ACCENT : 'var(--ov-outline-variant)',
          transition: 'width 160ms ease, background 160ms ease',
        }} />
      ))}
    </div>
  );
}

function Hero({ icon, title, subtitle }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 14, padding: '4px 0 14px' }}>
      <AccentIconChip icon={icon} color={ACCENT} size={48} />
      <div>
        <div style={{ font: 'var(--ov-weight-semibold) var(--ov-title-lg-size)/1.15 ' + SANS, color: OV }}>{title}</div>
        <div style={{ font: 'var(--ov-weight-regular) var(--ov-body-md-size)/1.35 ' + SANS, color: OVV, marginTop: 2 }}>{subtitle}</div>
      </div>
    </div>
  );
}

function Footer({ children }) {
  return <div style={{ padding: '10px 16px 8px', display: 'flex', flexDirection: 'column', gap: 10 }}>{children}</div>;
}

// ── Step 1: role choice ──────────────────────────────────────────────────────

function RoleStep({ onHost, onGuest, onBack }) {
  return (
    <div>
      <TopBar title="Sync with another phone" onBack={onBack} />
      <div style={{ padding: '0 16px' }}>
        <StepDots index={0} count={6} />
        <Hero icon="devices" title="Move your data, no cloud"
          subtitle="Copy Health Connect records straight to another phone over Bluetooth. Nothing leaves your devices." />

        <Card variant="neutral" padding={16} onClick={onHost} style={{ display: 'flex', gap: 14, alignItems: 'center', marginTop: 4 }}>
          <AccentIconChip icon="wifi_tethering" color={ACCENT} size={44} />
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ font: 'var(--ov-weight-semibold) var(--ov-title-md-size)/1.25 ' + SANS, color: OV }}>Make this phone discoverable</div>
            <div style={{ font: 'var(--ov-weight-regular) var(--ov-body-md-size)/1.35 ' + SANS, color: OVV, marginTop: 2 }}>Show a code the other phone types in.</div>
          </div>
          <Icon name="chevron_right" size={24} color={OVV} />
        </Card>

        <Card variant="neutral" padding={16} onClick={onGuest} style={{ display: 'flex', gap: 14, alignItems: 'center', marginTop: 10 }}>
          <AccentIconChip icon="phonelink_ring" color={ACCENT} size={44} />
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ font: 'var(--ov-weight-semibold) var(--ov-title-md-size)/1.25 ' + SANS, color: OV }}>Find a phone to sync with</div>
            <div style={{ font: 'var(--ov-weight-regular) var(--ov-body-md-size)/1.35 ' + SANS, color: OVV, marginTop: 2 }}>Scan nearby and enter its code.</div>
          </div>
          <Icon name="chevron_right" size={24} color={OVV} />
        </Card>

        <div style={{ display: 'flex', gap: 10, marginTop: 16, padding: '12px 14px', borderRadius: 'var(--ov-radius-sm)',
          background: 'var(--ov-surface-container)' }}>
          <Icon name="lock" size={20} color={OVV} />
          <div style={{ font: 'var(--ov-weight-regular) var(--ov-body-sm-size)/1.4 ' + SANS, color: OVV }}>
            Transfer runs on a paired, encrypted Bluetooth link. OpenVitals has no internet permission — this never touches a network.
          </div>
        </div>
      </div>
    </div>
  );
}

// ── Step 2 (host): discoverable + code ───────────────────────────────────────

function HostStep({ code, seconds, connecting, onCancel, onSimulateConnect }) {
  return (
    <div>
      <TopBar title="Discoverable" onBack={onCancel} />
      <div style={{ padding: '0 16px' }}>
        <StepDots index={1} count={6} />
        <Hero icon="wifi_tethering" title="Waiting for the other phone"
          subtitle="On the other phone, choose “Find a phone”, tap this device, and type the code below." />

        <Card variant="accent" accentColor={ACCENT} padding={22} style={{ textAlign: 'center', marginTop: 4 }}>
          <div style={{ font: 'var(--ov-weight-medium) var(--ov-label-lg-size)/1 ' + SANS, color: OVV, letterSpacing: '.06em', textTransform: 'uppercase' }}>Pairing code</div>
          <div style={{ marginTop: 12, display: 'flex', justifyContent: 'center', gap: 10 }}>
            {code.split('').map((d, i) => (
              <span key={i} style={{ width: 40, height: 56, borderRadius: 12, background: 'var(--ov-surface-container-highest)',
                display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
                font: 'var(--ov-weight-bold) var(--ov-headline-sm-size)/1 ' + SANS, color: OV, fontFeatureSettings: "'tnum'" }}>{d}</span>
            ))}
          </div>
          <div style={{ marginTop: 16, display: 'inline-flex', alignItems: 'center', gap: 8, color: OVV,
            font: 'var(--ov-weight-medium) var(--ov-body-md-size)/1 ' + SANS }}>
            {connecting
              ? (<><Icon name="sync" size={18} color={ACCENT} /> A phone is connecting…</>)
              : (<><Icon name="schedule" size={18} color={OVV} /> Visible for {seconds}s</>)}
          </div>
        </Card>

        <div style={{ marginTop: 14 }}>
          <DetailRow label="This phone" value="Pixel 8 · Manuel" />
          <DetailRow label="Bluetooth" value="On · paired link" />
        </div>
      </div>
      <Footer>
        {/* Prototype-only affordance to advance the click-through. */}
        <Button variant="tonal" fullWidth size="large" icon="smartphone" onClick={onSimulateConnect}>Simulate incoming connection</Button>
        <Button variant="text" fullWidth onClick={onCancel}>Cancel</Button>
      </Footer>
    </div>
  );
}

// ── Step 2 (guest): scan → code entry ────────────────────────────────────────

const NEARBY = [
  ['Pixel 8 · Manuel', 'heart_check', true],
  ['Galaxy S23', 'smartphone', false],
  ['Tab S9', 'tablet', false],
];

function GuestStep({ phase, selected, codeEntry, onPick, onDigit, onBack, onConnect, error }) {
  if (phase === 'code') {
    const full = codeEntry.length === 6;
    return (
      <div>
        <TopBar title="Enter code" onBack={onBack} />
        <div style={{ padding: '0 16px' }}>
          <StepDots index={1} count={6} />
          <Hero icon="password" title={'Code from ' + selected}
            subtitle="Type the six digits shown on the other phone to confirm it's really that device." />

          <div style={{ display: 'flex', justifyContent: 'center', gap: 10, marginTop: 6 }}>
            {Array.from({ length: 6 }).map((_, i) => (
              <span key={i} style={{ width: 40, height: 56, borderRadius: 12,
                background: 'var(--ov-surface-container-highest)',
                border: i === codeEntry.length ? '2px solid ' + ACCENT : '2px solid transparent',
                display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
                font: 'var(--ov-weight-bold) var(--ov-headline-sm-size)/1 ' + SANS, color: OV, fontFeatureSettings: "'tnum'" }}>{codeEntry[i] || ''}</span>
            ))}
          </div>

          {error ? (
            <div style={{ marginTop: 14, display: 'flex', gap: 10, alignItems: 'center', padding: '12px 14px',
              borderRadius: 'var(--ov-radius-sm)', background: 'var(--ov-error-container)', color: 'var(--ov-on-error-container)' }}>
              <Icon name="error" size={20} /> <span style={{ font: 'var(--ov-weight-regular) var(--ov-body-md-size)/1.35 ' + SANS }}>That code didn't match. Check the other phone and try again.</span>
            </div>
          ) : null}

          <div style={{ marginTop: 18, display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 10 }}>
            {['1','2','3','4','5','6','7','8','9','','0','del'].map((k, i) => k === '' ? <span key={i} /> : (
              <button key={i} type="button" onClick={() => onDigit(k)}
                style={{ height: 56, borderRadius: 'var(--ov-radius-md)', border: 'none', cursor: 'pointer',
                  background: 'var(--ov-surface-container)', color: OV,
                  font: 'var(--ov-weight-medium) var(--ov-title-lg-size)/1 ' + SANS }}>
                {k === 'del' ? <Icon name="backspace" size={22} color={OVV} /> : k}
              </button>
            ))}
          </div>
        </div>
        <Footer>
          <Button variant="filled" fullWidth size="large" disabled={!full} onClick={onConnect}>Connect</Button>
        </Footer>
      </div>
    );
  }

  return (
    <div>
      <TopBar title="Find a phone" onBack={onBack} />
      <div style={{ padding: '0 16px' }}>
        <StepDots index={1} count={6} />
        <Hero icon="bluetooth_searching" title="Scanning nearby"
          subtitle="Pick the phone showing a pairing code. Make sure it's discoverable." />
        <SectionHeader text="NEARBY DEVICES" trailing="refresh" />
        {NEARBY.map(([name, icon, isOv]) => (
          <Card key={name} variant="neutral" padding={16} onClick={() => onPick(name)}
            style={{ display: 'flex', gap: 14, alignItems: 'center', marginBottom: 10 }}>
            <AccentIconChip icon={icon} color={isOv ? ACCENT : OVV} size={40} />
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ font: 'var(--ov-weight-semibold) var(--ov-title-md-size)/1.2 ' + SANS, color: OV }}>{name}</div>
              <div style={{ font: 'var(--ov-weight-regular) var(--ov-body-sm-size)/1.3 ' + SANS, color: OVV, marginTop: 1 }}>
                {isOv ? 'Running OpenVitals' : 'Bluetooth device'}
              </div>
            </div>
            <Icon name="chevron_right" size={24} color={OVV} />
          </Card>
        ))}
        <div style={{ display: 'flex', gap: 8, alignItems: 'center', justifyContent: 'center', padding: '8px 0', color: OVV,
          font: 'var(--ov-weight-medium) var(--ov-body-md-size)/1 ' + SANS }}>
          <Icon name="progress_activity" size={18} color={OVV} /> Still scanning…
        </div>
      </div>
    </div>
  );
}

// ── Step 3: time range ───────────────────────────────────────────────────────

function RangeStep({ range, onRange, onBack, onNext }) {
  return (
    <div>
      <TopBar title="How far back" onBack={onBack} />
      <div style={{ padding: '0 16px' }}>
        <StepDots index={2} count={6} />
        <Hero icon="history" title="How far back to sync"
          subtitle="Older data takes longer to read and send. You can always run it again for more." />
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginTop: 4 }}>
          {RANGE_LABELS.map((label) => {
            const sel = label === range;
            return (
              <button key={label} type="button" onClick={() => onRange(label)}
                style={{ padding: '18px 14px', borderRadius: 'var(--ov-radius-md)', cursor: 'pointer', textAlign: 'left',
                  border: sel ? '2px solid ' + ACCENT : '1px solid var(--ov-outline-variant)',
                  background: sel ? 'color-mix(in srgb, ' + ACCENT + ' 9%, var(--ov-surface-container))' : 'transparent',
                  color: OV, font: 'var(--ov-weight-semibold) var(--ov-title-md-size)/1 ' + SANS }}>
                {label === 'All' ? 'Everything' : 'Last ' + label}
              </button>
            );
          })}
        </div>
        <div style={{ marginTop: 12, display: 'flex', gap: 10, alignItems: 'center', padding: '12px 14px',
          borderRadius: 'var(--ov-radius-sm)', background: 'var(--ov-surface-container)' }}>
          <Icon name="event" size={20} color={OVV} />
          <span style={{ font: 'var(--ov-weight-regular) var(--ov-body-md-size)/1.35 ' + SANS, color: OVV }}>
            {range === 'All' ? 'From your earliest record onward.' : 'From ' + rangeStart(range) + ' to today.'}
          </span>
        </div>
      </div>
      <Footer>
        <Button variant="filled" fullWidth size="large" icon="arrow_forward" iconPosition="trailing" onClick={onNext}>Choose data types</Button>
      </Footer>
    </div>
  );
}

function rangeStart(range) {
  if (range === '30 days') return 'Jun 20, 2026';
  if (range === '6 months') return 'Jan 20, 2026';
  return 'Jul 20, 2025';
}

// ── Step 4: data types ───────────────────────────────────────────────────────

function TypesStep({ selected, onToggle, onAll, onBack, onSync }) {
  const count = selected.size;
  return (
    <div>
      <TopBar title="Data types" onBack={onBack}
        actions={[{ label: count === CATEGORIES.length ? 'Clear all' : 'Select all', onClick: onAll }]} />
      <div style={{ padding: '0 16px' }}>
        <StepDots index={3} count={6} />
        <Hero icon="checklist" title="What to accept"
          subtitle="Both phones agreed on the types below. Uncheck anything you'd rather not sync." />
        {CATEGORIES.map(([key, name, icon, color, desc]) => {
          const on = selected.has(key);
          return (
            <Card key={key} variant="neutral" padding={14} onClick={() => onToggle(key)}
              style={{ display: 'flex', gap: 14, alignItems: 'center', marginBottom: 10 }}>
              <AccentIconChip icon={icon} color={color} size={40} />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ font: 'var(--ov-weight-semibold) var(--ov-title-md-size)/1.2 ' + SANS, color: OV }}>{name}</div>
                <div style={{ font: 'var(--ov-weight-regular) var(--ov-body-sm-size)/1.3 ' + SANS, color: OVV, marginTop: 1 }}>{desc}</div>
              </div>
              <Checkbox checked={on} onChange={() => onToggle(key)} />
            </Card>
          );
        })}
      </div>
      <Footer>
        <Button variant="filled" fullWidth size="large" icon="sync" disabled={count === 0} onClick={onSync}>
          {count === 0 ? 'Pick at least one type' : 'Start sync · ' + count + ' selected'}
        </Button>
      </Footer>
    </div>
  );
}

// ── Step 5: transfer progress ────────────────────────────────────────────────

function ProgressStep({ pct, sent, received, written, phaseLabel, onCancel }) {
  return (
    <div>
      <TopBar title="Syncing" />
      <div style={{ padding: '0 16px' }}>
        <StepDots index={4} count={6} />
        <Hero icon="sync" title="Syncing with Galaxy S23"
          subtitle="Keep both phones nearby and awake. This screen can go to the background." />

        <Card variant="metric" padding={20} style={{ textAlign: 'center' }}>
          <div style={{ font: 'var(--ov-weight-bold) var(--ov-display-sm-size, 40px)/1 ' + SANS, color: OV, fontFeatureSettings: "'tnum'" }}>{pct}%</div>
          <div style={{ marginTop: 6, font: 'var(--ov-weight-medium) var(--ov-body-md-size)/1 ' + SANS, color: OVV }}>{phaseLabel}</div>
          <div style={{ marginTop: 16, height: 8, borderRadius: 999, background: 'var(--ov-outline-variant)', position: 'relative', overflow: 'hidden' }}>
            <div style={{ position: 'absolute', inset: 0, right: 'auto', width: pct + '%', borderRadius: 999, background: ACCENT, transition: 'width 300ms ease' }} />
          </div>
        </Card>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 10, marginTop: 12 }}>
          {[['Sent', sent, 'upload'], ['Received', received, 'download'], ['Written', written, 'check_circle']].map(([label, n, icon]) => (
            <Card key={label} variant="neutral" padding={14} style={{ textAlign: 'center' }}>
              <Icon name={icon} size={20} color={OVV} />
              <div style={{ marginTop: 6, font: 'var(--ov-weight-semibold) var(--ov-title-lg-size)/1 ' + SANS, color: OV, fontFeatureSettings: "'tnum'" }}>{n.toLocaleString()}</div>
              <div style={{ font: 'var(--ov-weight-regular) var(--ov-body-sm-size)/1 ' + SANS, color: OVV, marginTop: 2 }}>{label}</div>
            </Card>
          ))}
        </div>
      </div>
      <Footer>
        <Button variant="outlined" fullWidth onClick={onCancel}>Cancel sync</Button>
      </Footer>
    </div>
  );
}

// ── Step 6: report ───────────────────────────────────────────────────────────

const REPORT_ROWS = [
  ['Activity', 4210, 180],
  ['Heart', 8640, 512],
  ['Sleep', 96, 12],
  ['Body', 143, 20],
  ['Vitals', 271, 8],
  ['Nutrition', 512, 44],
];

function ReportStep({ onDone }) {
  const imported = REPORT_ROWS.reduce((s, r) => s + r[1], 0);
  const duplicates = REPORT_ROWS.reduce((s, r) => s + r[2], 0);
  return (
    <div>
      <TopBar title="Sync complete" />
      <div style={{ padding: '0 16px' }}>
        <StepDots index={5} count={6} />
        <div style={{ textAlign: 'center', padding: '8px 0 14px' }}>
          <AccentIconChip icon="task_alt" color="var(--ov-metric-active)" size={56} iconSize={30} />
          <div style={{ marginTop: 10, font: 'var(--ov-weight-semibold) var(--ov-headline-sm-size)/1.15 ' + SANS, color: OV }}>Merged {imported.toLocaleString()} records</div>
          <div style={{ marginTop: 4, font: 'var(--ov-weight-regular) var(--ov-body-md-size)/1.35 ' + SANS, color: OVV }}>
            from Galaxy S23 into Health Connect
          </div>
        </div>

        <Card variant="neutral" padding={16}>
          <DetailRow label="Imported" value={imported.toLocaleString()} />
          <DetailRow label="Already had (skipped)" value={duplicates.toLocaleString()} />
          <DetailRow label="Not selected" value="0" />
          <DetailRow label="Unsupported" value="3" />
          <DetailRow label="Failed" value="0" />
        </Card>

        <SectionHeader text="BY DATA TYPE" style={{ marginTop: 8 }} />
        <Card variant="neutral" padding={16}>
          {REPORT_ROWS.map(([name, imp, dup], i) => (
            <div key={name} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center',
              padding: '10px 0', borderTop: i === 0 ? 'none' : '1px solid var(--ov-outline-variant)' }}>
              <span style={{ font: 'var(--ov-weight-medium) var(--ov-body-lg-size)/1 ' + SANS, color: OV }}>{name}</span>
              <span style={{ font: 'var(--ov-weight-regular) var(--ov-body-md-size)/1 ' + SANS, color: OVV, fontFeatureSettings: "'tnum'" }}>
                +{imp.toLocaleString()} · {dup} dup
              </span>
            </div>
          ))}
        </Card>

        <div style={{ display: 'flex', gap: 10, marginTop: 14 }}>
          <Button variant="outlined" fullWidth icon="content_copy">Copy report</Button>
          <Button variant="outlined" fullWidth icon="download">Save report</Button>
        </div>
      </div>
      <Footer>
        <Button variant="filled" fullWidth size="large" icon="done" onClick={onDone}>Done</Button>
      </Footer>
    </div>
  );
}

// ── Wizard host ──────────────────────────────────────────────────────────────

function DeviceSyncScreen({ nav }) {
  const [step, setStep] = React.useState('role'); // role|host|guest|range|types|progress|report
  const [guestPhase, setGuestPhase] = React.useState('scan'); // scan|code
  const [picked, setPicked] = React.useState('');
  const [codeEntry, setCodeEntry] = React.useState('');
  const [codeError, setCodeError] = React.useState(false);
  const [range, setRange] = React.useState('1 year');
  const [types, setTypes] = React.useState(() => new Set(CATEGORIES.map((c) => c[0])));

  // Prototype transfer animation.
  const [pct, setPct] = React.useState(0);
  React.useEffect(() => {
    if (step !== 'progress') return;
    setPct(0);
    const id = setInterval(() => {
      setPct((p) => {
        if (p >= 100) { clearInterval(id); setTimeout(() => setStep('report'), 500); return 100; }
        return Math.min(100, p + 7);
      });
    }, 260);
    return () => clearInterval(id);
  }, [step]);

  const toggle = (k) => setTypes((prev) => {
    const next = new Set(prev);
    if (next.has(k)) next.delete(k); else next.add(k);
    return next;
  });
  const toggleAll = () => setTypes((prev) =>
    prev.size === CATEGORIES.length ? new Set() : new Set(CATEGORIES.map((c) => c[0])));

  const onDigit = (k) => {
    setCodeError(false);
    if (k === 'del') { setCodeEntry((c) => c.slice(0, -1)); return; }
    setCodeEntry((c) => (c.length >= 6 ? c : c + k));
  };
  const onConnect = () => {
    // Prototype: "999999" demonstrates the wrong-code error state; anything else proceeds.
    if (codeEntry === '999999') { setCodeError(true); setCodeEntry(''); return; }
    setStep('range');
  };

  const phaseLabel =
    pct < 20 ? 'Handshake and dedup check' :
    pct < 85 ? 'Exchanging records' :
    pct < 100 ? 'Writing to Health Connect' : 'Building report';

  const sent = Math.round(13876 * pct / 100);
  const received = Math.round(14012 * pct / 100);
  const written = Math.round(13876 * Math.max(0, pct - 15) / 100);

  switch (step) {
    case 'host':
      return <HostStep code="428913" seconds={112} connecting={false}
        onCancel={() => setStep('role')} onSimulateConnect={() => setStep('range')} />;
    case 'guest':
      return <GuestStep phase={guestPhase} selected={picked} codeEntry={codeEntry} error={codeError}
        onPick={(name) => { setPicked(name); setGuestPhase('code'); }}
        onDigit={onDigit}
        onConnect={onConnect}
        onBack={() => { if (guestPhase === 'code') { setGuestPhase('scan'); setCodeEntry(''); setCodeError(false); } else setStep('role'); }} />;
    case 'range':
      return <RangeStep range={range} onRange={setRange} onBack={() => setStep('role')} onNext={() => setStep('types')} />;
    case 'types':
      return <TypesStep selected={types} onToggle={toggle} onAll={toggleAll} onBack={() => setStep('range')} onSync={() => setStep('progress')} />;
    case 'progress':
      return <ProgressStep pct={pct} sent={sent} received={received} written={written} phaseLabel={phaseLabel} onCancel={() => setStep('types')} />;
    case 'report':
      return <ReportStep onDone={() => nav('settings')} />;
    case 'role':
    default:
      return <RoleStep onHost={() => setStep('host')} onGuest={() => { setGuestPhase('scan'); setStep('guest'); }} onBack={() => nav('settings')} />;
  }
}

Object.assign(window, { DeviceSyncScreen });
