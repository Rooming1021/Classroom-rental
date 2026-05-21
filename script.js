const classrooms = [
  { name: "1-7", floor: "1F", type: "classroom", status: "reservable" },
  { name: "1-8", floor: "1F", type: "classroom", status: "available" },
  { name: "1-9", floor: "1F", type: "classroom", status: "reservable" },
  { name: "2-7", floor: "2F", type: "classroom", status: "unavailable" },
  { name: "2-8", floor: "2F", type: "classroom", status: "reservable" },
  { name: "2-9", floor: "2F", type: "classroom", status: "available" },
  { name: "2-10", floor: "2F", type: "classroom", status: "unavailable" },
  { name: "컴퓨터실", floor: "2F", type: "special", status: "unavailable" },
  { name: "(1)수업나눔교실", floor: "2F", type: "special", status: "unavailable" },
  { name: "(2)수업나눔교실", floor: "2F", type: "special", status: "reservable" },
  { name: "Wee Class", floor: "2F", type: "special", status: "disabled" },
  { name: "수업혁신지원센터", floor: "2F", type: "special", status: "available" },
  { name: "진로진학활동실", floor: "2F", type: "special", status: "available" },
  { name: "진로진학상담실", floor: "2F", type: "special", status: "disabled" },
  { name: "학생생활지원실", floor: "2F", type: "special", status: "disabled" },
  { name: "다목적교실", floor: "2F", type: "special", status: "reservable" },
  { name: "음악실", floor: "3F", type: "special", status: "disabled" },
  { name: "미술실", floor: "3F", type: "special", status: "available" },
  { name: "과학실", floor: "4F", type: "special", status: "reservable" },
  { name: "자율학습실", floor: "4F", type: "special", status: "reservable" },
];

const statusMeta = {
  available: "대여 가능",
  reservable: "예약 가능",
  unavailable: "예약 불가",
  disabled: "사용 불가",
};

const activeState = {
  selected: null,
};

const availableSummary = document.querySelector("#availableSummary");
const contentLayout = document.querySelector("#contentLayout");
const classroomGrid = document.querySelector("#classroomGrid");
const resultSummary = document.querySelector("#resultSummary");
const closeDrawer = document.querySelector("#closeDrawer");
const drawerTitle = document.querySelector("#drawerTitle");
const drawerStatus = document.querySelector("#drawerStatus");
const reserveButton = document.querySelector("#reserveButton");

const pinIcon = `
  <svg viewBox="0 0 24 24" aria-hidden="true">
    <path d="m15 4 5 5-4 1-4 8-2-2-4 4 4-4-2-2 8-4 1-4Z" />
  </svg>
`;

function isBookable(room) {
  return room.status === "available" || room.status === "reservable";
}

function getVisibleRooms() {
  return classrooms.filter((room) => room.floor === "2F");
}

function updateSummary() {
  const bookableCount = classrooms.filter(isBookable).length;

  availableSummary.textContent = `현재 예약 가능 교실 ${bookableCount}개`;
  resultSummary.textContent = "교실 카드를 클릭하면 예약 상세 페이지로 이동합니다.";
}

function renderRooms() {
  const visibleRooms = getVisibleRooms();

  classroomGrid.innerHTML = "";

  visibleRooms.forEach((room) => {
    const card = document.createElement("button");

    card.className = "room-card";
    card.type = "button";
    card.dataset.status = room.status;
    card.dataset.name = room.name;
    card.setAttribute("aria-label", `${room.name} ${statusMeta[room.status]}`);

    if (activeState.selected === room.name) {
      card.classList.add("is-selected");
    }

    card.innerHTML = `
      <span class="room-text">
        <span class="room-name">${room.name}</span>
        <span class="room-status">${statusMeta[room.status]}</span>
      </span>
      <span class="pin-button" aria-hidden="true">
        ${pinIcon}
      </span>
    `;

    card.addEventListener("click", () => {
      activeState.selected = room.name;
      openDrawer(room);
      renderRooms();
    });

    classroomGrid.append(card);
  });

  updateSummary();
}

function openDrawer(room) {
  drawerTitle.textContent = room.name;
  drawerStatus.textContent = statusMeta[room.status];
  drawerStatus.dataset.status = room.status;
  reserveButton.disabled = !isBookable(room);
  reserveButton.textContent = isBookable(room) ? "예약하기" : "예약 불가";
  contentLayout.classList.add("is-detail-open");
}

closeDrawer.addEventListener("click", () => {
  activeState.selected = null;
  contentLayout.classList.remove("is-detail-open");
  renderRooms();
});

renderRooms();
