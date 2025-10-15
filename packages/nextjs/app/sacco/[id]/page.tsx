"use client";

import { useParams } from "next/navigation";
import { SaccoDetails } from "~~/components/sacco/SaccoDetails";

const SaccoDetailsPage = () => {
  const params = useParams();
  const id = params?.id as string;
  return <SaccoDetails groupId={id} />;
};

export default SaccoDetailsPage;


