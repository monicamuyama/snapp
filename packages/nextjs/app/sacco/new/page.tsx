"use client";

import { CreateSacco } from "~~/components/sacco/CreateSacco";

const NewSaccoPage = () => {
  return (
    <div className="px-4 py-6 max-w-xl mx-auto">
      <h1 className="text-2xl font-bold mb-4">Create a SACCO</h1>
      <CreateSacco />
    </div>
  );
};

export default NewSaccoPage;


