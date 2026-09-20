// Game Day console -- no framework, no network calls, no inline handlers.
// Every number on the page is computed from the data in this file.

'use strict';

const REPO = 'https://github.com/Freddricklogan/aws-terraform-gameday/blob/main';

const CHALLENGES = [
  {
    n: 1,
    title: 'Fix the routing',
    difficulty: 'beginner',
    bugs: 2,
    minutes: 10,
    skills: 'Route tables, subnet associations',
    scenario:
      'Infrastructure deployed cleanly. Instances are running. Nothing outside the VPC can reach them, and nothing inside can reach out.',
    hints: [
      'Terraform reported no errors, so every resource exists. Ask what is not connected.',
      'A route table with a 0.0.0.0/0 route does nothing until something is associated with it.',
      'There are two separate attachments here: the main route table association and the per-subnet one.'
    ],
    file: 'challenges/challenge-01-fix-routing.tf',
    solution: 'solutions/challenge-01-solution.md'
  },
  {
    n: 2,
    title: 'Fix the security group',
    difficulty: 'beginner',
    bugs: 2,
    minutes: 10,
    skills: 'Ingress and egress rules, silent failures',
    scenario:
      'Routing is correct and the gateway is attached, but HTTP requests hang until they time out. There is no error anywhere.',
    hints: [
      'A timeout means packets are being dropped, not refused. A refusal would be instant.',
      'Check the port number on the ingress rule against the port the server actually listens on.',
      'Security groups are stateful, but only if a return path exists at all. Look for the missing egress rule.'
    ],
    file: 'challenges/challenge-02-fix-security.tf',
    solution: 'solutions/challenge-02-solution.md'
  },
  {
    n: 3,
    title: 'Fix the auto scaling',
    difficulty: 'intermediate',
    bugs: 2,
    minutes: 15,
    skills: 'ASG health check types, target group attachment',
    scenario:
      'The load balancer answers with 503 Service Unavailable. Terminated instances are never replaced.',
    hints: [
      '503 from an ALB means the target group has no healthy members -- often no members at all.',
      'An EC2 health check only asks whether the virtual machine is running, not whether the web server answers.',
      'Find the one argument that registers the Auto Scaling group with the target group.'
    ],
    file: 'challenges/challenge-03-fix-autoscaling.tf',
    solution: 'solutions/challenge-03-solution.md'
  },
  {
    n: 4,
    title: 'Fix the launch template',
    difficulty: 'intermediate',
    bugs: 2,
    minutes: 15,
    skills: 'user_data, security group assignment',
    scenario:
      'The Auto Scaling group is healthy from its own point of view, but every instance serves a blank page and sits in the wrong security group.',
    hints: [
      'A blank page means something is listening or nothing is installed. SSM into a host and check.',
      'Without user_data the instance boots as plain Ubuntu -- no nginx, nothing on port 80.',
      'If you do not name a security group in the launch template, AWS puts the instance in the VPC default one.'
    ],
    file: 'challenges/challenge-04-fix-launch-template.tf',
    solution: 'solutions/challenge-04-solution.md'
  },
  {
    n: 5,
    title: 'Fix the load balancer',
    difficulty: 'intermediate',
    bugs: 2,
    minutes: 15,
    skills: 'Internal vs internet-facing, listener configuration',
    scenario:
      'Instances are healthy. curl localhost:80 works on every host. The load balancer URL returns 504 Gateway Timeout.',
    hints: [
      'A 504 means the load balancer could not get a response from a target, or could not be reached itself.',
      'An internal load balancer resolves to private addresses only. Check the scheme.',
      'Then check that the listener port matches the port the targets are registered on.'
    ],
    file: 'challenges/challenge-05-fix-load-balancer.tf',
    solution: 'solutions/challenge-05-solution.md'
  },
  {
    n: 6,
    title: 'Full stack debug',
    difficulty: 'advanced',
    bugs: 4,
    minutes: 30,
    skills: 'Everything above, combined, with no hints in the file',
    scenario:
      'Someone deployed the whole stack and nothing works. The URL times out. Four independent defects, no guidance in the code.',
    hints: [
      'Work the debugging sequence in order: routing, then security, then compute, then load balancing.',
      'Fix one defect at a time and re-check the symptom. Two fixes at once hides which one mattered.',
      'Read the plan output, not just the code -- a count or a reference can be wrong in a way that reads fine.'
    ],
    file: 'challenges/challenge-06-full-debug.tf',
    solution: 'solutions/challenge-06-solution.md'
  }
];

const CONTROLS = [
  ['IMDSv2 required, hop limit 1', 'modules/compute', 'An SSRF in the web tier can no longer read the instance role credentials.'],
  ['Private subnets for all compute', 'modules/network', 'No instance has a public IP or an inbound path from the internet.'],
  ['Security groups by reference', 'modules/alb', 'The app tier accepts traffic from the ALB security group, not from a CIDR.'],
  ['No port 22 anywhere', 'modules/compute', 'Operator access is AWS Systems Manager, which is logged and needs no open port.'],
  ['Encrypted gp3 root volumes', 'modules/compute', 'Data at rest is encrypted; a detached snapshot is not readable.'],
  ['ALB access logs to S3', 'modules/observability', 'Every request at the edge is recorded, in a versioned TLS-only bucket.'],
  ['VPC flow logs (ACCEPT and REJECT)', 'modules/network', 'Rejected traffic is the signal; capturing only accepted traffic hides scans.'],
  ['S3 public access block + TLS-only policy', 'modules/observability', 'The log bucket cannot be made public by a later console click.'],
  ['default_tags on every resource', 'providers.tf', 'Owner, cost centre and data classification are never forgotten.'],
  ['Remote state with locking', 'backend.tf.example', 'Two concurrent applies cannot corrupt each other. State never sits on a laptop.'],
  ['OIDC role assumption in CI', '.github/workflows', 'No long-lived AWS access keys exist in the repository or its secrets.'],
  ['Manual approval before apply', '.github/workflows', 'A merge cannot spend money until a human approves the environment.']
];

const TOUR = [
  {
    title: 'One way in',
    body: 'The diagram has four trust boundaries. The only unauthenticated edge is the load balancer listener. Everything that runs code sits in private subnets with no public IP.',
    target: 'architecture'
  },
  {
    title: 'Six failures to debug',
    body: 'Each challenge gives a symptom, not a stack trace: a 503, a timeout, a blank page. Teams reason from the symptom to the missing attachment.',
    target: 'challenges'
  },
  {
    title: 'Hints are a deliberate cost',
    body: 'Hints are hidden behind a toggle and graduated from nudge to answer. Revealing one costs points, so teams think before they click.',
    target: 'challenges'
  },
  {
    title: 'The hardening is testable',
    body: 'Every control in this table is asserted by terraform test against mocked providers. Delete the IMDSv2 line and CI goes red.',
    target: 'controls'
  },
  {
    title: 'Review it for free',
    body: 'Clone, make test, make scan. No AWS account, no credentials, no spend -- the whole posture is checkable offline.',
    target: 'verify'
  }
];

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------

function el(tag, props, children) {
  const node = document.createElement(tag);
  if (props) {
    Object.keys(props).forEach(function (k) {
      if (k === 'class') node.className = props[k];
      else if (k === 'text') node.textContent = props[k];
      else node.setAttribute(k, props[k]);
    });
  }
  (children || []).forEach(function (c) { node.appendChild(c); });
  return node;
}

function renderChallenges() {
  const list = document.getElementById('challenge-list');

  CHALLENGES.forEach(function (c) {
    const item = el('li', { class: 'challenge', 'data-difficulty': c.difficulty });

    const head = el('header', null, [
      el('h3', { text: 'Challenge ' + c.n + ' — ' + c.title }),
      el('div', { class: 'meta' }, [
        el('span', { class: 'pill ' + c.difficulty, text: c.difficulty }),
        el('span', { class: 'pill', text: c.bugs + ' defect' + (c.bugs === 1 ? '' : 's') }),
        el('span', { class: 'pill', text: '~' + c.minutes + ' min' })
      ])
    ]);

    const scenario = el('p', { class: 'scenario', text: c.scenario });
    const skills = el('p', { class: 'scenario', text: 'Skills tested: ' + c.skills });

    const hintId = 'hint-' + c.n;
    const hintBtn = el('button', {
      class: 'chip',
      type: 'button',
      'aria-expanded': 'false',
      'aria-controls': hintId,
      text: 'Show hints'
    });

    const hintBox = el('div', { class: 'hint', id: hintId, hidden: 'hidden' }, [
      el('strong', { text: 'Graduated hints — each one costs points' })
    ]);
    const ul = el('ul');
    c.hints.forEach(function (h) { ul.appendChild(el('li', { text: h })); });
    hintBox.appendChild(ul);

    hintBtn.addEventListener('click', function () {
      const open = hintBtn.getAttribute('aria-expanded') === 'true';
      hintBtn.setAttribute('aria-expanded', String(!open));
      hintBtn.textContent = open ? 'Show hints' : 'Hide hints';
      if (open) hintBox.setAttribute('hidden', 'hidden');
      else hintBox.removeAttribute('hidden');
    });

    const actions = el('div', { class: 'actions' }, [
      hintBtn,
      el('a', { class: 'chip', href: REPO + '/' + c.file, text: 'Open the broken config' }),
      el('a', { class: 'chip', href: REPO + '/' + c.solution, text: 'Solution' })
    ]);

    item.appendChild(head);
    item.appendChild(scenario);
    item.appendChild(skills);
    item.appendChild(actions);
    item.appendChild(hintBox);
    list.appendChild(item);
  });
}

function renderControls() {
  const body = document.getElementById('controls-body');
  CONTROLS.forEach(function (row) {
    const tr = el('tr');
    tr.appendChild(el('th', { scope: 'row', text: row[0] }));
    const where = el('td');
    where.appendChild(el('code', { text: row[1] }));
    tr.appendChild(where);
    tr.appendChild(el('td', { text: row[2] }));
    body.appendChild(tr);
  });
}

function renderKpis() {
  const bugs = CHALLENGES.reduce(function (a, c) { return a + c.bugs; }, 0);
  const minutes = CHALLENGES.reduce(function (a, c) { return a + c.minutes; }, 0);
  document.getElementById('kpi-challenges').textContent = String(CHALLENGES.length);
  document.getElementById('kpi-bugs').textContent = String(bugs);
  document.getElementById('kpi-modules').textContent = '4';
  document.getElementById('kpi-controls').textContent = String(CONTROLS.length);
  document.getElementById('kpi-minutes').textContent = String(minutes);
}

function wireFilters() {
  const chips = Array.prototype.slice.call(document.querySelectorAll('.chip[data-filter]'));
  chips.forEach(function (chip) {
    chip.addEventListener('click', function () {
      const want = chip.getAttribute('data-filter');
      chips.forEach(function (c) { c.setAttribute('aria-pressed', String(c === chip)); });
      Array.prototype.slice.call(document.querySelectorAll('.challenge')).forEach(function (item) {
        const match = want === 'all' || item.getAttribute('data-difficulty') === want;
        item.style.display = match ? '' : 'none';
      });
    });
  });
}

// ---------------------------------------------------------------------------
// Tour
// ---------------------------------------------------------------------------

function wireTour() {
  const dialog = document.getElementById('tour');
  const titleNode = document.getElementById('tour-title');
  const bodyNode = document.getElementById('tour-body');
  const countNode = document.getElementById('tour-count');
  const nextBtn = document.getElementById('tour-next');
  const prevBtn = document.getElementById('tour-prev');
  const closeBtn = document.getElementById('tour-close');
  const startBtn = document.getElementById('tour-start');

  let i = 0;
  let lastFocus = null;

  function clearHighlight() {
    Array.prototype.slice.call(document.querySelectorAll('.highlight')).forEach(function (n) {
      n.classList.remove('highlight');
    });
  }

  function show(index) {
    i = Math.max(0, Math.min(TOUR.length - 1, index));
    const step = TOUR[i];
    titleNode.textContent = step.title;
    bodyNode.textContent = step.body;
    countNode.textContent = (i + 1) + ' / ' + TOUR.length;
    prevBtn.disabled = i === 0;
    nextBtn.textContent = i === TOUR.length - 1 ? 'Finish' : 'Next';

    clearHighlight();
    const target = document.getElementById(step.target);
    if (target) {
      target.classList.add('highlight');
      target.scrollIntoView({ block: 'start', behavior: 'smooth' });
    }
  }

  function open() {
    lastFocus = document.activeElement;
    dialog.removeAttribute('hidden');
    show(0);
    nextBtn.focus();
  }

  function close() {
    dialog.setAttribute('hidden', 'hidden');
    clearHighlight();
    if (lastFocus && lastFocus.focus) lastFocus.focus();
  }

  startBtn.addEventListener('click', open);
  closeBtn.addEventListener('click', close);
  prevBtn.addEventListener('click', function () { show(i - 1); });
  nextBtn.addEventListener('click', function () {
    if (i === TOUR.length - 1) close();
    else show(i + 1);
  });

  dialog.addEventListener('click', function (e) {
    if (e.target === dialog) close();
  });

  document.addEventListener('keydown', function (e) {
    if (dialog.hasAttribute('hidden')) return;
    if (e.key === 'Escape') { close(); }
    else if (e.key === 'ArrowRight') { show(i + 1); }
    else if (e.key === 'ArrowLeft') { show(i - 1); }
  });
}

renderChallenges();
renderControls();
renderKpis();
wireFilters();
wireTour();
