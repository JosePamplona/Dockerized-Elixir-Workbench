// The project's first k6 script: a smoke test — five virtual users for
// fifteen seconds, asking the root page and expecting a 200. Run it with
// './wb.sh k6' (this file) or './wb.sh k6 other.js' (any script under
// k6/), against the deployment that is up. BASE_URL is set by the compose
// for the topology k6 runs in — the app on localhost inside the pod, the
// balancer or the `app` alias on the scaled network — so a script never
// names a host; run on its own, it falls back to a local app.
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = { vus: 5, duration: '15s' };

const BASE_URL = __ENV.BASE_URL || 'http://localhost:4000';

export default function () {
  const res = http.get(`${BASE_URL}/`);
  check(res, { 'status is 200': (r) => r.status === 200 });
  sleep(1);
}
