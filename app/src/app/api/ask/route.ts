import { NextResponse } from 'next/server';
import { executeQuery } from '@/lib/snowflake';
import { demoPlatform } from '@/lib/platform';

export const dynamic = 'force-dynamic';

// Only these fixed, read-only queries can run. The model never writes SQL; it
// only summarises rows returned here, so every answer is traceable to data.
const INTENTS: Record<string, { match: RegExp; sql: string }> = {
  instruments: {
    match: /fail|flag|sequencer|instrument|worst|highest|precision|yield/i,
    sql: `SELECT ENTITY_ID, ENTITY_NAME, REGION, CATEGORY, SAMPLE_COUNT, ROUND(YIELD_ATTAINMENT_PCT, 1) AS YIELD_ATTAINMENT_PCT,
       QC_FLAG_COUNT, QC_FAIL_COUNT, RERUN_COUNT, ROUND(FLAG_PRECISION_PCT, 1) AS FLAG_PRECISION_PCT
FROM CURATED.PERFORMANCE_SUMMARY
QUALIFY DENSE_RANK() OVER (ORDER BY QC_FAIL_COUNT DESC) <= 3
ORDER BY QC_FAIL_COUNT DESC, QC_FLAG_COUNT DESC`,
  },
  modes: {
    match: /mode|cause|type|why/i,
    sql: `SELECT FAILURE_MODE, QC_FLAG_COUNT, QC_FAIL_COUNT, RERUN_COUNT, ROUND(FLAG_PRECISION_PCT, 1) AS FLAG_PRECISION_PCT
FROM CURATED.FAILURE_MODE_SUMMARY ORDER BY QC_FAIL_COUNT DESC LIMIT 7`,
  },
  kpis: {
    match: /.*/,
    sql: `SELECT TITLE, DISPLAY, SOURCE_WATERMARK FROM CURATED.KPI_SUMMARY ORDER BY SORT_ORDER`,
  },
};

const DEFINITIONS =
  'Yield attainment = data output (GB) / target output (GB). QC flag precision = confirmed failed runs / QC flags. ' +
  'Reagent lot hold flags are site-wide and are never confirmed as instrument failures. Output is in gigabases (GB). ' +
  'All data is synthetic demo data.';

// provider 'cortex' = Snowflake AI_COMPLETE; 'bedrock' = Amazon Bedrock Claude
// via the external-access UDF APP.BEDROCK_GENERATE (aws/setup_aws.py).
async function summarise(question: string, rows: unknown[], provider: 'cortex' | 'bedrock' = 'cortex'): Promise<string> {
  const prompt =
    'You are a sequencing lab operations analyst for Harbourline Genomics, a fictional Singapore research network. Do not give clinical or diagnostic advice. Answer ONLY from the JSON rows and definitions below. ' +
    'If the rows do not answer the question, say so. Do not invent numbers. Keep it under 120 words.\n' +
    `Definitions: ${DEFINITIONS}\nRows: ${JSON.stringify(rows)}\nQuestion: ${question}`;
  const out = await executeQuery<{ R: string }>(
    provider === 'bedrock' ? 'SELECT APP.BEDROCK_GENERATE(?) AS R' : `SELECT AI_COMPLETE('claude-sonnet-4-5', ?) AS R`,
    [prompt],
  );
  const raw = String(out[0]?.R ?? '').trim();
  // AI_COMPLETE returns a JSON string literal; decode it when present.
  try {
    const parsed = JSON.parse(raw);
    return typeof parsed === 'string' ? parsed : raw;
  } catch {
    return raw;
  }
}

export async function POST(req: Request) {
  let body: any;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }
  const question = typeof body?.question === 'string' ? body.question.trim().slice(0, 2000) : '';
  const memo = body?.mode === 'memo';
  if (!memo && !question) return NextResponse.json({ error: 'Question required' }, { status: 400 });

  try {
    if (memo) {
      const provider = demoPlatform() === 'aws' ? 'bedrock' : 'cortex';
      const [kpis, instruments, modes, risk, bands] = await Promise.all([
        executeQuery(INTENTS.kpis.sql),
        executeQuery(INTENTS.instruments.sql),
        executeQuery(INTENTS.modes.sql),
        executeQuery(`SELECT ENTITY_ID, ROUND(FAIL_PROB_7D, 2) AS FAIL_PROB_7D, RISK_BAND
FROM ML.QC_FAIL_SCORES ORDER BY FAIL_PROB_7D DESC LIMIT 5`),
        executeQuery(`SELECT RISK_BAND, COUNT(*) AS SEQUENCERS FROM ML.QC_FAIL_SCORES GROUP BY RISK_BAND`),
      ]);
      const rows = { kpis, topFailedSequencers: instruments, failureModes: modes, top5ByRisk: risk, sequencersPerRiskBand: bands };
      const answer = await summarise(
        'Draft a short action memo for Dr Shalini Menon, Head of Sequencing Operations at Harbourline Genomics, with 3 prioritised actions, citing the figures.',
        [rows],
        provider,
      );
      return NextResponse.json({ answer, sources: rows, provider: provider === 'bedrock' ? 'Amazon Bedrock (Claude Sonnet 4.5)' : 'Snowflake Cortex AI_COMPLETE (claude-sonnet-4-5)', draft: true, synthetic: true });
    }
    const key = Object.keys(INTENTS).find((k) => INTENTS[k].match.test(question))!;
    const rows = await executeQuery(INTENTS[key].sql);
    const answer = await summarise(question, rows);
    return NextResponse.json({ answer, sql: INTENTS[key].sql, sources: rows, synthetic: true });
  } catch (err) {
    console.error('ask route failed', err);
    return NextResponse.json({ error: 'AI service unavailable' }, { status: 503 });
  }
}
