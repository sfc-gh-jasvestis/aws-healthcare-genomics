'use client';

import { useEffect, useState } from 'react';
import { AppLayout } from '@/components/AppLayout';
import { KPICard } from '@/components/KPICard';
import { Chart } from '@/components/Chart';
import { DataTable } from '@/components/DataTable';
import { AskAI } from '@/components/AskAI';
import { ActionMemo } from '@/components/ActionMemo';

interface SequencingData {
  platform: 'snowflake' | 'aws';
  kpiCards: { title: string; value: string }[];
  timeseries: { period: string; samples: number | null; flags: number | null }[];
  categories: { category: string; flags: number | null; failed: number | null }[];
  entities: Record<string, string | number | null>[];
  pmRisk: { name: string; compliance: number; failed: number }[];
  sourceWatermark: string | null;
  rawWatermark: string | null;
  requestedAt: string;
  stale: boolean;
  pipelineBehind: boolean;
  risk: Record<string, string | number | null>[];
  holdout: { n: number | null; baseRate: number | null; precision: number | null; recall: number | null } | null;
  forecast: { period: string; value: number | null; lower: number | null; upper: number | null }[];
  live: Record<string, string | number | null>[];
  liveSummary: { n: number | null; flags: number | null; lastLoaded: string | null; medianLagSeconds: number | null };
  anomalies: Record<string, string | number | null>[];
  alerts: Record<string, string | number | null>[];
}

const pct = (value: number | null) => (value === null ? 'n/a' : `${(value * 100).toFixed(0)}%`);

export default function HomePage() {
  const [data, setData] = useState<SequencingData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    const controller = new AbortController();
    setLoading(true);
    setError(null);
    setData(null);
    fetch('/api/data', { cache: 'no-store', signal: controller.signal })
      .then(async (response) => {
        if (!response.ok) throw new Error('Data request failed');
        const payload = await response.json();
        if (!Array.isArray(payload.kpiCards) || !Array.isArray(payload.entities)) throw new Error('Invalid contract');
        return payload;
      })
      .then(setData)
      .catch(() => {
        if (!controller.signal.aborted) setError('Snowflake data is unavailable. No fallback values are displayed.');
      })
      .finally(() => { if (!controller.signal.aborted) setLoading(false); });
    return () => controller.abort();
  }, [attempt]);

  const isAws = (data?.platform ?? 'aws') === 'aws';
  const awsDiagram = { key: 'aws', title: 'AWS + Snowflake', src: '/architecture-aws.html' };
  const sfDiagram = { key: 'snowflake', title: 'Snowflake Only', src: '/architecture-snowflake.html' };
  const diagrams = isAws ? [awsDiagram, sfDiagram] : [sfDiagram, awsDiagram];
  const kpiVal = (title: string) => data?.kpiCards.find((card) => card.title === title)?.value ?? 'Unavailable';
  const executive = (
    <div className="space-y-6">
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {['Yield Attainment', 'Samples Sequenced', 'Data Output (TB)', 'QC Flag Precision'].map((title) => (
          <KPICard key={title} title={title} value={kpiVal(title)} status="neutral" />
        ))}
      </div>
      <p className="text-sm text-slate-600">Yield attainment = data output (GB) / target output (GB). QC flag precision = confirmed failed runs / runs flagged by run QC. All counts are aggregate per sequencer and day; there are no sample-level records.</p>
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <Chart data={data?.timeseries ?? []} type="line" xKey="period"
          yKeys={[{ key: 'samples', name: 'Samples sequenced' }, { key: 'flags', name: 'QC flags' }]} title="Daily Samples Sequenced and QC Flags" />
        <Chart data={data?.categories ?? []} type="bar" xKey="category"
          yKeys={[{ key: 'flags', name: 'QC flags' }, { key: 'failed', name: 'Confirmed failed runs' }]} title="QC Flags and Confirmed Failed Runs by Failure Mode" />
      </div>
      <DataTable columns={[
        { key: 'id', header: 'Sequencer' }, { key: 'region', header: 'Lab site' }, { key: 'category', header: 'Assay' },
        { key: 'samples', header: 'Samples' }, { key: 'yieldPct', header: 'Yield (%)' }, { key: 'outputTb', header: 'Output (TB)' },
        { key: 'flags', header: 'QC flags' }, { key: 'failed', header: 'Failed runs' }, { key: 'precision', header: 'Precision (%)' },
      ]} data={data?.entities ?? []} title="Sequencer observations" />
    </div>
  );
  const predictive = (
    <div className="space-y-4">
      <h2 className="font-semibold">7-day failed-run risk and sample volume forecast</h2>
      <p className="text-sm text-slate-600">
        Snowflake ML classification predicts the probability that a sequencer has a confirmed failed run in the next 7 days,
        from phasing, low-Q30 tile share, recent failed runs, utilisation tier, instrument age and assay.
      </p>
      {data?.holdout ? (
        <p role="status" className="text-sm text-slate-700">
          Out-of-time holdout ({data.holdout.n} instrument-days): precision {pct(data.holdout.precision)} and recall{' '}
          {pct(data.holdout.recall)} at a 0.5 threshold, versus a {pct(data.holdout.baseRate)} base rate.
        </p>
      ) : (
        <p role="status">Model outputs are not deployed. Run snowflake/05_ml.sql.</p>
      )}
      <DataTable columns={[
        { key: 'id', header: 'Sequencer' }, { key: 'band', header: 'Risk band' },
        { key: 'probability', header: 'P(failed run in 7 days)' }, { key: 'scoredAsOf', header: 'Scored as of' },
      ]} data={data?.risk ?? []} title="Failed-run risk by sequencer" />
      <Chart data={data?.forecast ?? []} type="line" xKey="period"
        yKeys={[{ key: 'value', name: 'Forecast' }, { key: 'lower', name: 'Lower' }, { key: 'upper', name: 'Upper' }]}
        title="Network-wide sample volume forecast, next 14 days (samples per day)" />
      <DataTable columns={[
        { key: 'id', header: 'Sequencer' }, { key: 'date', header: 'Date' }, { key: 'phasing', header: 'Phasing (%)' },
        { key: 'expected', header: 'Expected' }, { key: 'upper', header: 'Upper bound' },
      ]} data={data?.anomalies ?? []} title="Phasing anomalies, last 15 days (Snowflake ML anomaly detection, trained on the prior 75 days)" />
    </div>
  );
  const liveTab = (
    <div className="space-y-4">
      <h2 className="font-semibold">{isAws ? 'Live runs: S3 upload to Snowpipe' : 'Live runs: Snowflake-native simulator'}</h2>
      <p className="text-sm text-slate-600">
        {isAws
          ? 'Simulated sequencer run-completion summaries are uploaded to the S3 landing bucket under runs/ (aws/publish_runs.py), and Snowpipe auto-ingest loads them into RAW.LIVE_RUNS.'
          : 'CALL APP.SIMULATE_RUNS(n) inserts simulated sequencer run-completion summaries directly into RAW.LIVE_RUNS (or resume APP.TASK_SIMULATE_RUNS for a feed every minute). This simulates a run-summary feed; it is not Snowpipe Streaming.'}
        {' '}The alert APP.LIVE_RUN_ALERT logs QC_FLAG events and emails the on-call lab QC scientist.
      </p>
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <KPICard title="Run summaries loaded" value={String(data?.liveSummary?.n ?? 'n/a')} />
        <KPICard title="QC_FLAG events" value={String(data?.liveSummary?.flags ?? 'n/a')} />
        <KPICard title={isAws ? 'Median send to table lag (s)' : 'Median generated to table lag (s)'} value={String(data?.liveSummary?.medianLagSeconds ?? 'n/a')} />
        <KPICard title="Last load" value={data?.liveSummary?.lastLoaded ?? 'none'} />
      </div>
      <DataTable columns={[
        { key: 'id', header: 'Sequencer' }, { key: 'eventTs', header: 'Event (UTC)' }, { key: 'amount', header: 'Output (GB)' },
        { key: 'phasing', header: 'Phasing (%)' }, { key: 'status', header: 'Status' }, { key: 'loadedAt', header: 'Loaded' },
      ]} data={data?.live ?? []} title="Latest 25 run summaries" />
      <DataTable columns={[
        { key: 'id', header: 'Sequencer' }, { key: 'eventTs', header: 'Event (UTC)' }, { key: 'amount', header: 'Output (GB)' },
        { key: 'phasing', header: 'Phasing (%)' }, { key: 'hint', header: 'Action hint' },
      ]} data={data?.alerts ?? []} title="Run QC flag log" />
    </div>
  );
  const planning = (
    <div className="space-y-6">
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <KPICard title="PM Compliance" value={kpiVal('PM Compliance')} />
        <KPICard title="Reagent Kit Coverage" value={kpiVal('Reagent Kit Coverage')} />
        <KPICard title="Kits On Order" value={kpiVal('Kits On Order')} />
      </div>
      <Chart data={data?.pmRisk ?? []} type="scatter" xKey="compliance" xName="PM compliance"
        yKeys={[{ key: 'failed', name: 'Confirmed failed runs' }]} yDomain={[0, 'auto']}
        title="Preventive maintenance compliance (%) vs confirmed failed runs by sequencer" />
      <p className="text-sm text-slate-600">Synthetic associations are not evidence that maintenance prevented failures.</p>
      <ActionMemo persona={{ name: 'Dr Shalini Menon', role: 'Head of Sequencing Operations (fictional persona)' }} context={{}}
        onGenerate={async () => {
          const r = await fetch('/api/ask', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ mode: 'memo' }) });
          if (!r.ok) throw new Error('memo failed');
          const j = await r.json();
          return { subject: 'Draft sequencing operations actions (synthetic data, human review required)', body: j.answer, urgency: 'review', actions: [] };
        }} />
      <p role="status" className="text-sm text-slate-600">{isAws ? 'Draft generated by Amazon Bedrock (Claude) through a Snowflake external-access function' : 'Draft generated by Snowflake Cortex AI_COMPLETE (Claude Sonnet 4.5)'}, from the KPI, sequencer, failure-mode and risk tables only. No notification is sent.</p>
    </div>
  );
  const ai = (
    <div className="space-y-4">
      <p role="status">Answers come from the Cortex Agent APP.SEQUENCING_AGENT. It uses Cortex Analyst over the semantic view APP.SEQUENCING_ANALYTICS for metrics, and Cortex Search over synthetic run QC troubleshooting SOPs for procedures. The generated SQL is shown with each answer.</p>
      <div className="h-[500px]">
        <AskAI title="Ask the sequencing agent" mode="advisor" sampleQuestions={['Which 3 sequencers have the most confirmed failed runs?', 'Which sequencers are high risk this week and what SOP applies?', 'What is the yield attainment by assay?']}
          onSubmit={async (question) => {
            const r = await fetch('/api/agent', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ question }) });
            if (!r.ok) throw new Error('agent failed');
            const j = await r.json();
            const cites = j.sops?.length ? `\n\nSOPs: ${j.sops.join(', ')}` : '';
            return { answer: `${j.answer}${cites}`, sql: j.sql ?? undefined };
          }} />
      </div>
    </div>
  );
  const architecture = (
    <div className="space-y-4">
      {diagrams.map((d, i) => (
        <div key={d.key} className="space-y-2">
          <h2 className="font-semibold">Architecture: {d.title}{i === 0 ? ' (this deployment)' : ''}</h2>
          <iframe src={d.src} title={`${d.title} architecture diagram`} className="h-[620px] w-full rounded border border-slate-200" />
          <p className="text-sm text-slate-600">Hover a component for details. <a className="underline" href={d.src} target="_blank" rel="noreferrer">Open full screen</a></p>
        </div>
      ))}
      <h2 className="font-semibold">Implementation status</h2>
      <p>Core source: synthetic sequencers for Harbourline Genomics, a fictional Singapore research network (8 lab sites in Singapore planning areas x 5 assays), daily instrument observations and reagent kit stock. There are no patient, sample-level or variant records. Curated dynamic tables compute numerator/denominator metrics and are suspended after on-demand initialization.</p>
      <p>Application: Next.js server queries the explicit curated contract. Request time and source observation watermark are separate.</p>
      <p>ML: SNOWFLAKE.ML.CLASSIFICATION failed-run risk model evaluated on a time-based holdout, plus a 14-day sample volume FORECAST with prediction intervals.</p>
      <p>ML: ANOMALY_DETECTION flags phasing outliers per sequencer over the last 15 days.</p>
      <p>AI: Cortex Agent (Cortex Analyst over a semantic view, plus Cortex Search over SOPs) answers questions. The action memo uses {isAws ? 'Amazon Bedrock Claude through an external-access UDF' : 'Cortex AI_COMPLETE (Claude Sonnet 4.5)'}.</p>
      {isAws ? (
        <>
          <p>AWS ingestion: run-summary batches uploaded to S3, then Snowpipe auto-ingest (SQS) into RAW.LIVE_RUNS, with a Snowflake alert and email on QC_FLAG events.</p>
          <p>QuickSight: Snowflake DIRECT_QUERY dashboard (daily samples, confirmed failed runs by sequencer, failed-run risk), with a Q topic.</p>
        </>
      ) : (
        <>
          <p>Ingestion: APP.SIMULATE_RUNS inserts simulated run summaries into RAW.LIVE_RUNS, with a Snowflake alert and email on QC_FLAG events. No AWS account is used.</p>
          <p>BI: this SPCS app is the dashboard; natural-language questions go to the Cortex Agent.</p>
        </>
      )}
      <p>Orchestration: the task graph APP.TASK_REFRESH_CURATED, then TASK_RESCORE_RISK, runs on demand. Alerts and tasks stay suspended between demos.</p>
    </div>
  );
  const tabs = [
    { id: 'executive-cockpit', label: 'Executive Cockpit', icon: '', content: executive },
    { id: 'predictive', label: 'Predictive', icon: '', content: predictive },
    { id: 'planning', label: 'Lab Readiness', icon: '', content: planning },
    { id: 'live', label: 'Live Runs', icon: '', content: liveTab },
    { id: 'ask-ai', label: 'Ask AI', icon: '', content: ai },
    { id: 'architecture', label: 'Architecture & Data', icon: '', content: architecture },
  ].map((tab) => ({ ...tab, content: tab.id === 'architecture' ? tab.content : (
    <div className="space-y-4">
      <p className="text-sm text-slate-600">Synthetic, aggregate demo data for a fictional research sequencing lab network. No patient or genomic records; not for clinical use.</p>
      {loading ? <p role="status">Loading Snowflake data...</p> : error ? (
        <div role="alert" className="rounded border border-red-200 p-4">
          <p>{error}</p>
          <button className="mt-3 rounded border px-3 py-2" onClick={() => setAttempt((value) => value + 1)}>Retry data connection</button>
        </div>
      ) : !data?.entities.length ? <p role="status">No sequencer observations are available in this snapshot.</p> : (
        <>
          <p className="text-sm">Observation watermark: {data.sourceWatermark ?? 'Unavailable'}. Request time: {data.requestedAt}.</p>
          {(data.stale || data.pipelineBehind) && <p role="status" className="text-amber-700">Stale or lagging snapshot. Refresh the on-demand pipeline before presenting current results.</p>}
          {tab.content}
        </>
      )}
    </div>
  ) }));
  return <AppLayout title="Singapore Genomic Sequencing Lab Operations" tabs={tabs} />;
}
